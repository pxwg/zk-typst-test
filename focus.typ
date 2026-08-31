// Stable Tinymist entry point. Neovim selects the active note through the
// instance-local `zk-focus-id` input; all other notes keep only their heading.
#import "zk-diagnostics.typ": zk_emit_focused_diagnostics
#include "link.typ"
#context {
  zk_emit_focused_diagnostics()
}
