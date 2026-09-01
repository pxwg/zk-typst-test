use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use anyhow::{Context, Result, bail};
use typst::diag::{FileError, FileResult};
use typst::foundations::{Bytes, Datetime, Dict};
use typst::syntax::{FileId, Source, VirtualPath};
use typst::text::{Font, FontBook};
use typst::utils::LazyHash;
use typst::{Library, LibraryExt, World};
use typst_kit::fonts::{FontSearcher, FontSlot};

/// The files and configuration used by one evaluation. Sources are cached so
/// later span resolution sees exactly the text that Typst compiled.
pub struct ProjectWorld {
    root: PathBuf,
    main: FileId,
    library: LazyHash<Library>,
    book: LazyHash<FontBook>,
    fonts: Vec<FontSlot>,
    overlays: HashMap<PathBuf, String>,
    sources: Mutex<HashMap<FileId, Source>>,
    files: Mutex<HashMap<FileId, Bytes>>,
}

impl ProjectWorld {
    pub fn new(
        root: impl AsRef<Path>,
        entry: impl AsRef<Path>,
        inputs: Dict,
        overlays: HashMap<PathBuf, String>,
    ) -> Result<Arc<Self>> {
        let root = root.as_ref().canonicalize().with_context(|| {
            format!("failed to resolve project root {}", root.as_ref().display())
        })?;
        let entry = entry.as_ref();
        if entry.is_absolute() {
            bail!("entry path must be relative to the project root");
        }

        let main = FileId::new(None, VirtualPath::new(entry));
        let fonts = FontSearcher::new().include_system_fonts(false).search();
        let library = Library::builder().with_inputs(inputs).build();

        Ok(Arc::new(Self {
            root,
            main,
            library: LazyHash::new(library),
            book: LazyHash::new(fonts.book),
            fonts: fonts.fonts,
            overlays,
            sources: Mutex::new(HashMap::new()),
            files: Mutex::new(HashMap::new()),
        }))
    }

    pub fn path_for(&self, id: FileId) -> FileResult<PathBuf> {
        if id.package().is_some() {
            return Err(FileError::NotFound(id.vpath().as_rootless_path().into()));
        }
        id.vpath()
            .resolve(&self.root)
            .ok_or_else(|| FileError::AccessDenied)
    }

    fn load_source(&self, id: FileId) -> FileResult<Source> {
        if let Some(source) = self.sources.lock().unwrap().get(&id) {
            return Ok(source.clone());
        }

        let path = self.path_for(id)?;
        let text = if let Some(text) = self.overlays.get(&path) {
            text.clone()
        } else {
            fs::read_to_string(&path).map_err(|error| FileError::from_io(error, &path))?
        };
        let source = Source::new(id, text);
        self.sources.lock().unwrap().insert(id, source.clone());
        Ok(source)
    }

    fn load_file(&self, id: FileId) -> FileResult<Bytes> {
        if let Some(bytes) = self.files.lock().unwrap().get(&id) {
            return Ok(bytes.clone());
        }

        let path = self.path_for(id)?;
        let bytes = Bytes::new(fs::read(&path).map_err(|error| FileError::from_io(error, &path))?);
        self.files.lock().unwrap().insert(id, bytes.clone());
        Ok(bytes)
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
        self.load_source(id)
    }

    fn file(&self, id: FileId) -> FileResult<Bytes> {
        self.load_file(id)
    }

    fn font(&self, index: usize) -> Option<Font> {
        self.fonts.get(index)?.get()
    }

    fn today(&self, _offset: Option<i64>) -> Option<Datetime> {
        None
    }
}
