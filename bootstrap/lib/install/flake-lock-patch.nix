# Patch git+ssh GitHub nodes in a flake.lock to type=github (for access-tokens).
lockFile:
let
  lock = builtins.fromJSON (builtins.readFile lockFile);
  parseSlug = url:
    let p = builtins.match ".*github\\.com/([^/]+)/([^/.]+).*" url;
    in if p == null then null else { owner = builtins.elemAt p 0; repo = builtins.elemAt p 1; };
  patchNode = _name: node:
    let l = node.locked or null;
    in if l == null || (l.type or "") != "git" then node
    else let u = l.url or "";
    in if builtins.match ".*github\\.com/.*" u == null then node
    else let slug = parseSlug u; in
      if slug == null then node else node // {
        locked = builtins.removeAttrs l [ "url" "ref" "revCount" ] // {
          type = "github";
          owner = slug.owner;
          repo = slug.repo;
        };
        original = { type = "github"; owner = slug.owner; repo = slug.repo; };
      };
  nodes = builtins.mapAttrs patchNode lock.nodes;
in builtins.toJSON (lock // { nodes = nodes; })
