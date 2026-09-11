use std::collections::HashMap;
use std::fs;
use std::ops::Range;
use std::path::{Component, Path, PathBuf};
use std::sync::Mutex;

use anyhow::{Context, Result, bail};
use typst::diag::{FileError, FileResult};
use typst::foundations::{Bytes, Datetime, Dict};
use typst::syntax::{FileId, Source, Span, VirtualPath};
use typst::text::{Font, FontBook};
use typst::utils::LazyHash;
use typst::{Library, LibraryExt, World};
use typst_kit::fonts::{FontSearcher, FontSlot};

/// Files and configuration retained across Typst evaluations.
pub struct ProjectWorld {
    root: PathBuf,
    main: FileId,
    inputs: Dict,
    library: LazyHash<Library>,
    book: LazyHash<FontBook>,
    fonts: Vec<FontSlot>,
    slots: Mutex<HashMap<FileId, FileSlot>>,
}

impl ProjectWorld {
    pub fn new(root: impl AsRef<Path>, entry: impl AsRef<Path>, inputs: Dict) -> Result<Self> {
        let root = root.as_ref().canonicalize().with_context(|| {
            format!("failed to resolve project root {}", root.as_ref().display())
        })?;
        if !root.is_dir() {
            bail!("project root must be a directory");
        }
        let main = entry_id(entry.as_ref())?;
        let fonts = FontSearcher::new().include_system_fonts(false).search();
        let library = Library::builder().with_inputs(inputs.clone()).build();

        Ok(Self {
            root,
            main,
            inputs,
            library: LazyHash::new(library),
            book: LazyHash::new(fonts.book),
            fonts: fonts.fonts,
            slots: Mutex::new(HashMap::new()),
        })
    }

    /// Begin another evaluation. This does not discard unchanged sources.
    ///
    /// Files are read once on their first access in the new evaluation, including
    /// files that previously failed to load. Inputs replace, rather than merge
    /// with, the previous inputs. Invalid entries leave the world unchanged.
    pub fn prepare(&mut self, entry: impl AsRef<Path>, inputs: Dict) -> Result<()> {
        let main = entry_id(entry.as_ref())?;
        self.main = main;
        if self.inputs != inputs {
            self.library = LazyHash::new(Library::builder().with_inputs(inputs.clone()).build());
            self.inputs = inputs;
        }
        let slots = self.slots.get_mut().unwrap();
        // Do not accumulate files from every entry ever evaluated. Snapshots
        // independently retain any sources still needed by their callers.
        slots.retain(|_, slot| slot.accessed);
        for slot in slots.values_mut() {
            slot.accessed = false;
        }
        Ok(())
    }

    pub fn path_for(&self, id: FileId) -> FileResult<PathBuf> {
        path_for(&self.root, id)
    }

    /// Capture the sources actually observed in this evaluation, without disk IO.
    pub fn snapshot(&self) -> SourceSnapshot {
        let sources = self
            .slots
            .lock()
            .unwrap()
            .iter()
            .filter(|(_, slot)| slot.accessed && !slot.source_stale)
            .filter_map(|(&id, slot)| {
                slot.source
                    .as_ref()?
                    .as_ref()
                    .ok()
                    .map(|source| (id, source.clone()))
            })
            .collect();
        SourceSnapshot {
            root: self.root.clone(),
            sources,
        }
    }

    fn with_slot<T>(&self, id: FileId, f: impl FnOnce(&mut FileSlot) -> T) -> T {
        let mut slots = self.slots.lock().unwrap();
        let slot = slots.entry(id).or_default();
        if !slot.accessed {
            let bytes = self.path_for(id).and_then(|path| {
                fs::read(&path)
                    .map(Bytes::new)
                    .map_err(|error| FileError::from_io(error, &path))
            });
            if slot.bytes.as_ref() != Some(&bytes) {
                slot.source_stale = true;
                slot.bytes = Some(bytes);
            }
            slot.accessed = true;
        }
        f(slot)
    }
}

impl World for ProjectWorld {
    fn library(&self) -> &LazyHash<Library> {
        &self.library
    }

    fn book(&self) -> &LazyHash<FontBook> {
        &self.book
    }

    fn main(&self) -> FileId {
        self.main
    }

    fn source(&self, id: FileId) -> FileResult<Source> {
        self.with_slot(id, |slot| slot.source(id))
    }

    fn file(&self, id: FileId) -> FileResult<Bytes> {
        self.with_slot(id, |slot| slot.bytes.as_ref().unwrap().clone())
    }

    fn font(&self, index: usize) -> Option<Font> {
        self.fonts.get(index)?.get()
    }

    fn today(&self, _offset: Option<i64>) -> Option<Datetime> {
        None
    }
}

#[derive(Default)]
struct FileSlot {
    // Both source() and file() use these same bytes for the whole evaluation.
    bytes: Option<FileResult<Bytes>>,
    source: Option<FileResult<Source>>,
    source_stale: bool,
    accessed: bool,
}

impl FileSlot {
    fn source(&mut self, id: FileId) -> FileResult<Source> {
        if self.source_stale || self.source.is_none() {
            let previous = self.source.take().and_then(Result::ok);
            let source = self.bytes.as_ref().unwrap().clone().and_then(|bytes| {
                let text = std::str::from_utf8(&bytes)?;
                Ok(if let Some(mut source) = previous {
                    source.replace(text);
                    source
                } else {
                    Source::new(id, text.to_owned())
                })
            });
            self.source = Some(source);
            self.source_stale = false;
        }
        self.source.as_ref().unwrap().clone()
    }
}

/// Source provenance for one evaluation. Never reads from the live world or disk.
///
/// Typst sources are cheap, copy-on-write clones: later edits cannot change this
/// snapshot's text or span resolution. This is a record of the bytes observed
/// while evaluating, not an atomic snapshot of the entire filesystem.
#[derive(Clone)]
pub struct SourceSnapshot {
    root: PathBuf,
    sources: HashMap<FileId, Source>,
}

impl SourceSnapshot {
    pub fn source(&self, id: FileId) -> Option<&Source> {
        self.sources.get(&id)
    }

    pub fn path_for(&self, id: FileId) -> FileResult<PathBuf> {
        path_for(&self.root, id)
    }

    pub fn range(&self, span: Span) -> Option<Range<usize>> {
        let source = self.source(span.id()?)?;
        span.range().or_else(|| source.range(span))
    }
}

fn path_for(root: &Path, id: FileId) -> FileResult<PathBuf> {
    if id.package().is_some() {
        return Err(FileError::NotFound(id.vpath().as_rootless_path().into()));
    }
    id.vpath().resolve(root).ok_or(FileError::AccessDenied)
}

fn entry_id(entry: &Path) -> Result<FileId> {
    if entry.is_absolute()
        || entry
            .components()
            .any(|part| matches!(part, Component::ParentDir))
        || !entry
            .components()
            .any(|part| matches!(part, Component::Normal(_)))
    {
        bail!("entry must be a non-empty project-relative path without '..'");
    }
    Ok(FileId::new(None, VirtualPath::new(entry)))
}
