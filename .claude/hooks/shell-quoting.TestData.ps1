# Datos compartidos de las matrices de shell-quoting.Tests.ps1, pr-base-guard.Tests.ps1 y
# gh-account-guard.Tests.ps1 (Issue #370). Los metadatos son declarativos (escritos a mano,
# no calculados por el codigo bajo prueba): 'ident' = el prefijo hace que el comando real NO sea
# reconocible como git/gh de forma segura, asi que el segmento debe quedar sin vaciar.

$script:MatrixPrefixes = @(
    @{ p = '';                          ident = $false }
    @{ p = 'FOO=a ';                    ident = $false }
    @{ p = 'FOO="a b" ';                ident = $false }
    @{ p = "FOO='a b' ";                ident = $false }
    @{ p = 'A="x y" B=z ';              ident = $false }
    @{ p = 'VAR=x"y z" ';               ident = $false }
    @{ p = 'FOO= ';                     ident = $false }
    @{ p = 'FOO="" ';                   ident = $false }
    @{ p = "FOO=a`tBAR=b ";             ident = $false }
    @{ p = 'FOO=a\ b ';                 ident = $false }
    @{ p = 'FOO="a=b;c" ';              ident = $false }
    @{ p = "FOO='`$(x)' ";              ident = $false }
    @{ p = 'A=1 B="x y" ';              ident = $false }
    @{ p = 'FOO="sudo git" ';           ident = $false }
    @{ p = "FOO='a git' ";              ident = $false }
    @{ p = 'FOO="a git" ';              ident = $false }
    @{ p = 'FOO=x"a git" ';             ident = $false }
    @{ p = "FOO=x'a git' ";             ident = $false }
    @{ p = 'FOO=-"a git" ';             ident = $false }
    @{ p = 'FOO=x"a gh" ';              ident = $false }
    @{ p = 'A=1 FOO=x"a git" ';         ident = $false }
    @{ p = 'FOO=~"a git" ';             ident = $false }
    @{ p = 'FOO="a"git ';               ident = $false }
    @{ p = 'FOO=a"b git" ';             ident = $false }
    @{ p = 'FOO=x=y"a git" ';           ident = $false }
    @{ p = 'FOO=$(echo git) ';          ident = $true }
    @{ p = 'FOO=$(echo a b) ';          ident = $true }
    @{ p = 'FOO=`echo git` ';           ident = $true }
    @{ p = 'FOO=${X:-git} ';            ident = $true }
    @{ p = 'FOO=$((1+1)) ';             ident = $true }
    @{ p = 'FOO="$(echo git)" ';        ident = $true }
    @{ p = 'FOO=x$(echo git) ';         ident = $true }
    @{ p = 'FOO=${ cmd; } ';            ident = $true }
    @{ p = 'FOO="a $(b) c" ';           ident = $true }
    @{ p = 'FOO=$(echo git ) ';         ident = $true }
    @{ p = 'FOO="a b ';                 ident = $true }
    @{ p = 'FOO=\"a git\" ';            ident = $true }
    @{ p = "FOO=`$'a git' ";            ident = $true }
    @{ p = 'FOO=$"a git" ';             ident = $true }
    @{ p = '1A=x ';                     ident = $true }
    @{ p = 'A+=x ';                     ident = $true }
)

$script:MatrixWrappers = @('', 'sudo ', 'env ', 'command ', 'time env command sudo ')

# 'git' = true: cola que invoca git/gh de verdad, donde el texto del flag es dato.
# {0} se reemplaza por el texto del payload.
$script:MatrixTails = @(
    @{ t = 'git commit -m "{0}"';           git = $true }
    @{ t = 'git commit -am "{0}"';          git = $true }
    @{ t = 'git commit --message "{0}"';    git = $true }
    @{ t = 'gh issue create -t "{0}"';      git = $true }
    @{ t = 'sudo -b "{0}"';                 git = $false }
    @{ t = 'sudo -t "{0}"';                 git = $false }
    @{ t = 'watch -t "{0}"';                git = $false }
    @{ t = 'bash -c "{0}"';                 git = $false }
    @{ t = 'sudo -b "x --body ''{0}''"';    git = $false }
    @{ t = 'sudo --body "{0}"';             git = $false }
    @{ t = 'sudo --body="{0}"';             git = $false }
)

function Get-MatrixCases {
    param([string]$Payload)
    foreach ($pre in $script:MatrixPrefixes) {
        foreach ($wrap in $script:MatrixWrappers) {
            foreach ($tail in $script:MatrixTails) {
                $cmd = $pre.p + $wrap + ($tail.t -f $Payload)
                [pscustomobject]@{
                    Command = $cmd
                    ExpectEmptied = ($tail.git -and -not $pre.ident)
                }
            }
        }
    }
}
