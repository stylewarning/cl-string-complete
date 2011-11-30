;;;; package.lisp
;;;; Copyright (c) 2011 Robert Smith

;;;; Declare the CL-STRING-COMPLETE package.

(defpackage #:cl-string-complete
  (:use #:cl)
  (:export
   ;;;;;;;;;;;;;;;;;;;;;; exact-completion.lisp ;;;;;;;;;;;;;;;;;;;;;;
   ;;#:completion-node                    ; type + function
   ;;#:make-completion-node
   ;;#:completion-node-p
   ;;#:completion-node.char
   ;;#:completion-node.endp
   ;;#:completion-node.left
   ;;#:completion-node.middle
   ;;#:completion-node.right
   
   #:completion-tree
   #:make-completion-tree
   #:completion-tree-p
   ;;#:completion-tree.root
   
   #:completion-tree-add
   #:completion-tree-add*
   #:completion-tree-contains-p

   ;;#:completion-node-travel
   #:compute-completions)
  (:documentation "String completion API."))