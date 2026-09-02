use std::path::PathBuf;

use anyhow::{Context, Result};
use clap::{ArgAction, Parser, ValueHint};
use typst::foundations::{Dict, Value};
use zk_eval::{ProjectWorld, eval};

#[derive(Parser)]
#[command(name = "zk-eval")]
struct Arguments {
    /// Path to the input Typst file.
    #[arg(value_name = "INPUT", value_hint = ValueHint::FilePath)]
    input: PathBuf,

    /// Configure the project root.
    #[arg(long, value_name = "DIR", value_hint = ValueHint::DirPath)]
    root: Option<PathBuf>,

    /// Add a string key-value pair visible through `sys.inputs`.
    #[arg(
        long = "input",
        value_name = "key=value",
        action = ArgAction::Append,
        value_parser = parse_sys_input_pair,
    )]
    inputs: Vec<(String, String)>,
}

fn main() -> Result<()> {
    let arguments = Arguments::parse();
    let input = arguments
        .input
        .canonicalize()
        .with_context(|| format!("failed to resolve input {}", arguments.input.display()))?;
    let root = arguments
        .root
        .as_deref()
        .or_else(|| input.parent())
        .context("input has no parent directory")?
        .canonicalize()
        .context("failed to resolve project root")?;
    let entry = input.strip_prefix(&root).with_context(|| {
        format!(
            "input {} is outside project root {}",
            input.display(),
            root.display(),
        )
    })?;

    let inputs = arguments
        .inputs
        .into_iter()
        .map(|(key, value)| (key.into(), Value::Str(value.into())))
        .collect::<Dict>();
    let world = ProjectWorld::new(root, entry, inputs)?;
    let evaluated = eval(&world);
    for warning in evaluated.warnings {
        eprintln!("warning: {}", warning.message);
    }

    let output = evaluated.output?;
    serde_json::to_writer_pretty(std::io::stdout(), &output)?;
    println!();
    Ok(())
}

fn parse_sys_input_pair(raw: &str) -> Result<(String, String), String> {
    let (key, value) = raw
        .split_once('=')
        .ok_or("input must be a key and a value separated by an equal sign")?;
    let key = key.trim().to_owned();
    if key.is_empty() {
        return Err("the key was missing or empty".to_owned());
    }
    Ok((key, value.trim().to_owned()))
}
