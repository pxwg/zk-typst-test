// Stable Tinymist entry point. Neovim selects the active note through the
// instance-local `zk-focus-id` input; all other notes keep only their heading.
#import "zk-diagnostics.typ": zk_emit_focused_diagnostics
#import "zk-helpers.typ": zk_output_focused

#include "link.typ"
#context {
  zk_emit_focused_diagnostics()
  if sys.inputs.at("zk-repl", default: "false") == "true" {
    zk_output_focused()
  }
}
