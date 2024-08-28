using Downloads

const NAUTY_VERSION = "2_8_9"
const NAUTY_URL = "https://pallini.di.uniroma1.it/nauty$NAUTY_VERSION.tar.gz"
const WORDSIZE = 64

tarball = Downloads.download(NAUTY_URL)
run(`tar xvzf $tarball -C $(@__DIR__)`)

nautydir = joinpath(@__DIR__, "nauty$NAUTY_VERSION")
nautyfiles = joinpath.(nautydir, ["nauty.c", "nautil.c", "naugraph.c", "schreier.c", "naurng.c"])
nautywrap = joinpath(@__DIR__, "wrapper.c")
bindir = joinpath(@__DIR__, "..", "bin")
if !isdir(bindir)
    mkdir(bindir)
end

libpath = joinpath(bindir, "densenauty.so")
run(`gcc -DWORDSIZE=$WORDSIZE -DUSE_TLS -O3 -shared -fPIC -I $nautydir $nautyfiles $nautywrap -o $libpath`)
