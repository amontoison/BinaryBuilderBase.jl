using BinDeps2
using Base.Test
using SHA
using Compat

# The platform we're running on
const platform = BinDeps2.platform_suffix()

# On windows, the `.exe` extension is very important
const exe_ext = is_windows() ? ".exe" : ""

# We are going to build/install libfoo a lot, so here's our function to make sure the
# library is working properly
function check_foo(fooifier_path = "fooifier$(exe_ext)",
                   libfoo_path = "libfoo.$(Libdl.dlext)")
    # We know that foo(a, b) returns 2*a^2 - b
    result = 2*2.2^2 - 1.1

    # Test that we can invoke fooifier
    @test !success(`$fooifier_path`)
    @test success(`$fooifier_path 1.5 2.0`)
    @test parse(Float64,readchomp(`$fooifier_path 2.2 1.1`)) ≈ result

    # Test that we can dlopen() libfoo and invoke it directly
    libfoo = Libdl.dlopen_e(libfoo_path)
    @test libfoo != C_NULL
    foo = Libdl.dlsym_e(libfoo, :foo)
    @test foo != C_NULL
    @test ccall(foo, Cdouble, (Cdouble, Cdouble), 2.2, 1.1) ≈ result
    Libdl.dlclose(libfoo)
end

# We always run the non-builder tests, as those should work everywhere and on all platforms
include("nonbuilder_tests.jl")

# We run the builder tests only if they are explicitly asked for
if get(ENV, "BINDEPS2_RUN_BUILDER_TESTS", "") == "true"
    info("Running builder tests...")
    include("builder_tests.jl")
else
    info("Not running builder tests, to do so set BINDEPS2_RUN_BUILDER_TESTS=true.")
end
