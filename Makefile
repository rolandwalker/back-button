EMACS=emacs
# EMACS=/Applications/Emacs.app/Contents/MacOS/Emacs
# EMACS=/Applications/Emacs23.app/Contents/MacOS/Emacs
# EMACS=/Applications/Aquamacs.app/Contents/MacOS/Aquamacs
# EMACS=/Applications/Macmacs.app/Contents/MacOS/Emacs
# EMACS=/usr/local/bin/emacs
# EMACS=/opt/local/bin/emacs
# EMACS=/usr/bin/emacs
EMACS_FLAGS=-Q --batch

CURL=curl
WORK_DIR=$(shell pwd)
AUTOLOADS_FILE=$(shell basename `pwd`)-loaddefs.el
TEST_DIR=ert-tests
TEST_DEP_1=ert
TEST_DEP_1_URL=http://bzr.savannah.gnu.org/lh/emacs/emacs-24/download/head:/ert.el-20110112160650-056hnl9qhpjvjicy-2/ert.el

build :
	$(EMACS) $(EMACS_FLAGS) --eval             \
	    "(progn                                \
	      (setq byte-compile-error-on-warn t)  \
	      (batch-byte-compile))" *.el

test-dep-1 :
	@cd $(TEST_DIR)                                      && \
	$(EMACS) $(EMACS_FLAGS)  -L . -L .. -l $(TEST_DEP_1) || \
	(echo "Can't load test dependency $(TEST_DEP_1).el, run 'make downloads' to fetch it" ; exit 1)

downloads :
	$(CURL) '$(TEST_DEP_1_URL)' > $(TEST_DIR)/$(TEST_DEP_1).el

autoloads :
	$(EMACS) $(EMACS_FLAGS) --eval                       \
	    "(progn                                          \
	      (setq generated-autoload-file \"$(WORK_DIR)/$(AUTOLOADS_FILE)\") \
	      (update-directory-autoloads \"$(WORK_DIR)\"))"

test-autoloads : autoloads
	@$(EMACS) $(EMACS_FLAGS) -l "./$(AUTOLOADS_FILE)" || echo "failed to load autoloads: $(AUTOLOADS_FILE)"

test : build test-dep-1 test-autoloads
	@cd $(TEST_DIR)                                   && \
	(for test_lib in *-test.el; do                       \
	    $(EMACS) $(EMACS_FLAGS) -L . -L .. -l cl -l $(TEST_DEP_1) -l $$test_lib --eval \
	    "(flet ((ert--print-backtrace (&rest args)       \
	      (insert \"no backtrace in batch mode\")))      \
	       (ert-run-tests-batch-and-exit))" || exit 1;   \
	done)

clean :
	@rm -f $(AUTOLOADS_FILE) *.elc *~ */*.elc */*~ $(TEST_DIR)/$(TEST_DEP_1).el
