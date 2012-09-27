EMACS=emacs
# EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs
# EMACS=/Applications/Emacs23.app/Contents/MacOS/Emacs
# EMACS=/Applications/Aquamacs.app/Contents/MacOS/Aquamacs
# EMACS=/Applications/Macmacs.app/Contents/MacOS/Emacs
# EMACS=/usr/local/bin/emacs
# EMACS=/opt/local/bin/emacs
# EMACS=/usr/bin/emacs

INTERACTIVE_EMACS=/usr/local/bin/emacs
# can't find an OS X variant that works correctly for interactive tests:
# INTERACTIVE_EMACS=open -a Emacs.app --new --args
# INTERACTIVE_EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs
# INTERACTIVE_EMACS=/Applications/Emacs.app/Contents/MacOS/bin/emacs

EMACS_CLEAN=-Q
EMACS_BATCH=$(EMACS_CLEAN) --batch
TESTS=

CURL=curl --silent
EDITOR=runemacs -no_wait
WORK_DIR=$(shell pwd)
PACKAGE_NAME=$(shell basename $(WORK_DIR))
AUTOLOADS_FILE=$(PACKAGE_NAME)-loaddefs.el
TEST_DIR=ert-tests
TEST_DEP_1=ert
TEST_DEP_1_STABLE_URL=http://bzr.savannah.gnu.org/lh/emacs/emacs-24/download/head:/ert.el-20110112160650-056hnl9qhpjvjicy-2/ert.el
TEST_DEP_1_LATEST_URL=https://raw.github.com/emacsmirror/emacs/master/lisp/emacs-lisp/ert.el

build :
	$(EMACS) $(EMACS_BATCH) --eval             \
	    "(progn                                \
	      (setq byte-compile-error-on-warn t)  \
	      (batch-byte-compile))" *.el

test-dep-1 :
	@cd $(TEST_DIR)                                      && \
	$(EMACS) $(EMACS_BATCH)  -L . -L .. -l $(TEST_DEP_1) || \
	(echo "Can't load test dependency $(TEST_DEP_1).el, run 'make downloads' to fetch it" ; exit 1)

downloads :
	$(CURL) '$(TEST_DEP_1_STABLE_URL)' > $(TEST_DIR)/$(TEST_DEP_1).el

downloads-latest :
	$(CURL) '$(TEST_DEP_1_LATEST_URL)' > $(TEST_DIR)/$(TEST_DEP_1).el

autoloads :
	$(EMACS) $(EMACS_BATCH) --eval                       \
	    "(progn                                          \
	      (setq generated-autoload-file \"$(WORK_DIR)/$(AUTOLOADS_FILE)\") \
	      (update-directory-autoloads \"$(WORK_DIR)\"))"

test-autoloads : autoloads
	@$(EMACS) $(EMACS_BATCH) -l "./$(AUTOLOADS_FILE)" || echo "failed to load autoloads: $(AUTOLOADS_FILE)"

test : build test-dep-1 test-autoloads
	@cd $(TEST_DIR)                                   && \
	(for test_lib in *-test.el; do                       \
	    $(EMACS) $(EMACS_BATCH) -L . -L .. -l cl -l $(TEST_DEP_1) -l $$test_lib --eval \
	    "(flet ((ert--print-backtrace (&rest args)       \
	      (insert \"no backtrace in batch mode\")))      \
	       (ert-run-tests-batch-and-exit '(and \"$(TESTS)\" (not (tag :interactive)))))" || exit 1; \
	done)

test-interactive : build test-dep-1 test-autoloads
	@cd $(TEST_DIR)                                               && \
	(for test_lib in *-test.el; do                                   \
	    $(INTERACTIVE_EMACS) $(EMACS_CLEAN) --eval                   \
	    "(progn                                                      \
	      (cd \"$(WORK_DIR)/$(TEST_DIR)\")                           \
	      (setq dired-use-ls-dired nil)                              \
	      (setq frame-title-format \"TEST SESSION $(PACKAGE_NAME)\") \
	      (setq enable-local-variables :safe))"                      \
	    -L . -L .. -l cl -l $(TEST_DEP_1) -l $$test_lib              \
	    --visit $$test_lib --eval                                    \
	    "(progn                                                      \
	      (when (> (length \"$(TESTS)\") 0)                          \
	       (push \"\\\"$(TESTS)\\\"\" ert--selector-history))        \
	      (setq buffer-read-only t)                                  \
	      (setq cursor-in-echo-area t)                               \
	      (call-interactively 'ert-run-tests-interactively)          \
	      (ding)                                                     \
	      (when (y-or-n-p \"PRESS Y TO QUIT THIS TEST SESSION\")     \
	       (with-current-buffer \"*ert*\"                            \
	        (kill-emacs                                              \
	         (if (re-search-forward \"^Failed:[^\\n]+unexpected\" 500 t) 1 0)))))" || exit 1; \
	done)

clean :
	@rm -f $(AUTOLOADS_FILE) *.elc *~ */*.elc */*~ $(TEST_DIR)/$(TEST_DEP_1).el

edit :
	@$(EDITOR) `git ls-files`
