{ pkgs, ... }:

# Two-way wiki replica: ~/wiki <-> Hopper /media/simple/wiki (hub). fw13 is the other spoke.
# wiki_sync.py is a copy of fw13's ~/play/wiki-sync/wiki_sync.py; keep both in step.
# The SSH key and its Hopper authorization are machine state: see manual-steps.md.
let
  home = "/Users/miguel";
  state = "${home}/.local/state/wiki-sync";
  syncScript = ./wiki-sync/wiki_sync.py;
  config = pkgs.writeText "wiki-sync.json" (builtins.toJSON {
    roots = [ "${home}/wiki" "ssh://miguel@192.168.1.15//media/simple/wiki" ];
    inherit state;
    unison = "${pkgs.unison}/bin/unison";
    servercmd = "/home/miguel/.local/lib/wiki-sync/unison-server";
    ssh_identity = "${state}/id_ed25519";
    python_command = [ "${pkgs.python3}/bin/python3" ];
    pi_command = [ "${home}/.local/bin/pi" ];
    # Claude models via pi are unreliable here; Codex Sol/Astra are refused on a ChatGPT account.
    model = "openai-codex/gpt-6-luna";
    max_attempts = 2;
    max_llm_calls_per_run = 5;
    max_merge_bytes = 200000;
    resolver_timeout_seconds = 600;
    sync_timeout_seconds = 900;
  });
  wikiSync = pkgs.writeShellScriptBin "wiki-sync" ''
    mkdir -p ${home}/wiki
    exec ${pkgs.python3}/bin/python3 ${syncScript} --config ${config} "''${@:-status}"
  '';
in
{
  environment.systemPackages = [ pkgs.unison wikiSync ];

  launchd.user.agents.wiki-sync.serviceConfig = {
    ProgramArguments = [ "${wikiSync}/bin/wiki-sync" "run" "--resolve" ];
    # git merge-file (Xcode CLT) and node for pi.
    EnvironmentVariables.PATH = "/run/current-system/sw/bin:/usr/bin:/bin";
    StartInterval = 7200;
    RunAtLoad = true;
    Nice = 10;
    LowPriorityIO = true;
    ProcessType = "Background";
    StandardOutPath = "${state}/launchd.log";
    StandardErrorPath = "${state}/launchd.log";
  };
}
