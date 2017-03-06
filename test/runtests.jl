using TexExtensions
using Compat

using Base.Test

@test istextmime(MIME("text/mathtex+latex"))
