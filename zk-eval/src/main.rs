use std::path::PathBuf;

use anyhow::{Context, Result};
use clap::{ArgAction, Parser, Subcommand, ValueHint};
use typst::foundations::{Dict, Value};
use zk_eval::Runtime;

#[cfg(unix)]
mod rpc;

#[derive(Parser)]
#[command(
    name = "zk-eval",
    subcommand_negates_reqs = true,
    args_conflicts_with_subcommands = true
)]
struct Arguments {
    #[command(subcommand)]
    command: Option<Command>,

    /// Path to the input Typst file (one-shot evaluation).
    #[arg(value_name = "INPUT", value_hint = ValueHint::FilePath, required = true)]
    input: Option<PathBuf>,

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

#[derive(Subcommand)]
enum Command {
    /// Keep a project's Typst state alive and accept local JSON-RPC requests.
    Serve {
        #[arg(long, default_value = ".", value_name = "DIR", value_hint = ValueHint::DirPath)]
        root: PathBuf,
        #[arg(long, value_name = "PATH", value_hint = ValueHint::FilePath)]
        socket: PathBuf,
    },
}

fn main() -> Result<()> {
    let arguments = Arguments::parse();
    if let Some(Command::Serve { root, socket }) = arguments.command {
        #[cfg(unix)]
        return rpc::serve(&root, &socket);
        #[cfg(not(unix))]
        {
            let _ = (root, socket);
            anyhow::bail!("Unix socket serving is only available on Unix platforms");
        }
    }
    let input = arguments.input.context("input file is required")?;
    let input = input
        .canonicalize()
        .with_context(|| format!("failed to resolve input {}", input.display()))?;
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
    let mut runtime = Runtime::new(root)?;
    let evaluation = runtime.evaluate(entry, inputs)?;
    for warning in &evaluation.result.warnings {
        eprintln!("warning: {}", warning.message);
    }

    let output = evaluation
        .result
        .output
        .as_ref()
        .map_err(|error| anyhow::anyhow!("{error:#}"))?;
    serde_json::to_writer_pretty(std::io::stdout(), output)?;
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
