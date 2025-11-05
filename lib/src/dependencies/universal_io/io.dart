
library universal_io;

export 'src/_exports_in_vm.dart'
    if (dart.library.html) 'src/_exports_in_browser.dart'
    if (dart.library.js) 'src/_exports_in_nodejs.dart';
