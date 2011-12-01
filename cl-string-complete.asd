(defpackage #:cl-string-complete-asd
  (:use #:cl #:asdf))

(in-package #:cl-string-complete-asd)

(defsystem cl-string-complete
  :name "cl-string-complete"
  :version "0.1"
  :author "Robert Smith"
  :maintainer "Robert Smith"
  :description "Simple string completion in Common Lisp."
  :long-description "Simple string completion (finding suffixes of a
  string given a prefix) in Common Lisp."

  :serial t
  :components ((:file "package")
               (:file "exact-completion")))
