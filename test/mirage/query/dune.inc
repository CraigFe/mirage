
(rule
 (action
  (with-stdout-to name
  (with-stderr-to name.err
   (run ./config.exe query name)))))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff name.expected name)))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff name.err.expected name.err)))

(rule
 (action
  (with-stdout-to opam
  (with-stderr-to opam.err
   (run ./config.exe query opam)))))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff opam.expected opam)))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff opam.err.expected opam.err)))

(rule
 (action
  (with-stdout-to packages
  (with-stderr-to packages.err
   (run ./config.exe query packages)))))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff packages.expected packages)))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff packages.err.expected packages.err)))

(rule
 (action
  (with-stdout-to files-configure
  (with-stderr-to files-configure.err
   (run ./config.exe query files-configure)))))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff files-configure.expected files-configure)))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff files-configure.err.expected files-configure.err)))

(rule
 (action
  (with-stdout-to files-build
  (with-stderr-to files-build.err
   (run ./config.exe query files-build)))))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff files-build.expected files-build)))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff files-build.err.expected files-build.err)))

(rule
 (action
  (with-stdout-to Makefile
  (with-stderr-to Makefile.err
   (run ./config.exe query Makefile)))))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff Makefile.expected Makefile)))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff Makefile.err.expected Makefile.err)))

(rule
 (action
  (with-stdout-to Makefile.no-depext
  (with-stderr-to Makefile.no-depext.err
   (run ./config.exe query Makefile --no-depext)))))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff Makefile.no-depext.expected Makefile.no-depext)))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff Makefile.no-depext.err.expected Makefile.no-depext.err)))

(rule
 (action
  (with-stdout-to Makefile.depext
  (with-stderr-to Makefile.depext.err
   (run ./config.exe query Makefile --depext)))))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff Makefile.depext.expected Makefile.depext)))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff Makefile.depext.err.expected Makefile.depext.err)))

(rule
 (action
  (with-stdout-to version
  (with-stderr-to version.err
   (run ./config.exe query --version)))))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff version.expected version)))

(rule
 (alias runtest)
 (package mirage)
 (action
  (diff version.err.expected version.err)))
