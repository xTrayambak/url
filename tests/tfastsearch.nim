## Testing the fast-path for case insensitive view search
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import pkg/url/[views, search]

let x = toStringView("hello there. i am totally not losing my mind!")
echo findInsensitive(x, 'z')
