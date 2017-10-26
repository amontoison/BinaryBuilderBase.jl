const rootfs = "/data/keno/test/root"
const sandbox_path = joinpath(dirname(@__FILE__), "..", "deps", "sandbox")

"""
    UserNSRunner

A `UserNSRunner` represents an "execution context", an object that bundles all
necessary information to run commands within the container that contains
our crossbuild environment.  Use `run()` to actually run commands within the
`DockerRunner`, and `runshell()` as a quick way to get an interactive shell
within the crossbuild environment.
"""
type UserNSRunner
    sandbox_cmd::Cmd
    platform::Platform
end

function UserNSRunner(;cwd = nothing, workspace = nothing, platform::Platform = platform_key(), extra_env=Dict{String, String}())
    sandbox_cmd = `$sandbox_path --rootfs $rootfs`
    if workspace != nothing
        sandbox_cmd = `$sandbox_cmd --workspace $workspace`
    end
    if cwd != nothing
        sandbox_cmd = `$sandbox_cmd --cd $cwd`
    end
    sandbox_cmd = setenv(sandbox_cmd, merge(target_envs(triplet(platform)), extra_env))
    UserNSRunner(sandbox_cmd, platform)
end

function show(io::IO, x::UserNSRunner)
    p = x.platform
    # Displays as, e.g., Linux x86_64 (glibc) DockerRunner
    write(io, typeof(p), " ", arch(p), " ",
          Compat.Sys.islinux(p) ? "($(p.libc)) " : "",
          "UserNSRunner")
end

function run(ur::UserNSRunner, cmd, logpath::AbstractString; verbose::Bool = false)
    cd(dirname(sandbox_path))
    oc = OutputCollector(setenv(`$(ur.sandbox_cmd) $cmd`, ur.sandbox_cmd.env); verbose=verbose)

    did_succeed = wait(oc)

    # Write out the logfile, regardless of whether it was successful or not 
    mkpath(dirname(logpath))
    open(logpath, "w") do f
        # First write out the actual command, then the command output
        println(f, cmd)
        print(f, merge(oc))
    end

    # Return whether we succeeded or not
    return did_succeed
end

function runshell(ur::UserNSRunner)
    cd(dirname(sandbox_path))
    run(setenv(`$(ur.sandbox_cmd) /bin/bash`, ur.sandbox_cmd.env))
end
