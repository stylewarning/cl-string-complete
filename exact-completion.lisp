;;;; exact-completion.lisp
;;;; Copyright (c) 2011 Robert Smith

;;;; "Exact" string completion

(in-package #:cl-string-complete)

(declaim (optimize speed (safety 0) (debug 0)))

;;;;;;;;;;;;;;;;;;;;;; Completion node datatype ;;;;;;;;;;;;;;;;;;;;;;

(defstruct (completion-node (:conc-name completion-node.)
                            (:print-function completion-node-printer))
  (char   #\nul :type base-char :read-only t)
  (endp   nil   :type boolean)
  (left   nil   :type (or null completion-node))
  (middle nil   :type (or null completion-node))
  (right  nil   :type (or null completion-node)))

(defun completion-node-printer (obj stream depth)
  "Printer for ternary nodes."
  (declare (ignore depth))
  (print-unreadable-object (obj stream :type t :identity t)
    (princ "CHAR=" stream)
    (print (completion-node.char obj) stream)
    (princ " ENDP=" stream)
    (princ (completion-node.endp obj) stream)))

(defun completion-node (char)
  "Make a fresh ternary node. with character CHAR."
  (make-completion-node :char char))


;;;;;;;;;;;;;;;;;;;;;; Completion tree datatype ;;;;;;;;;;;;;;;;;;;;;;

(defstruct (completion-tree (:conc-name completion-tree.)
                            (:print-function completion-tree-printer))
  (root nil :type (or null completion-node)))

(defun completion-tree-printer (obj stream depth)
  "Printer for ternary trees."
  (declare (ignore depth))
  (print-unreadable-object (obj stream :type t :identity t)))


;;;;;;;;;;;;;;;;;;;; Completion tree modification ;;;;;;;;;;;;;;;;;;;;

(defun completion-tree-add (tree str)
  "Add a string STR to the ternary tree TREE."
  (labels ((completion-tree-add-node (pos node)
             (cond 
               ((char< (aref str pos)
                       (completion-node.char node))
                (unless (completion-node.left node)
                  (setf (completion-node.left node)
                        (completion-node (aref str pos))))
                (completion-tree-add-node pos (completion-node.left node)))
               
               ((char> (aref str pos)
                       (completion-node.char node))
                (unless (completion-node.right node)
                  (setf (completion-node.right node)
                        (completion-node (aref str pos))))
                (completion-tree-add-node pos (completion-node.right node)))
               
               (t (if (= (1+ pos) (length str))
                      (setf (completion-node.endp node) t)
                      (progn
                        (unless (completion-node.middle node)
                          (setf (completion-node.middle node)
                                (completion-node (aref str (1+ pos)))))
                        (completion-tree-add-node (1+ pos)
                                                  (completion-node.middle node))))))))
    (unless (completion-tree.root tree)
      (setf (completion-tree.root tree)
            (completion-node (aref str 0))))
    
    (completion-tree-add-node 0 (completion-tree.root tree))
    
    tree))

(defun completion-tree-add* (tree &rest strings)
  "Add a list of strings to TREE. The strings are suffled to help
balance the tree."
  ;; These functions are pilfered from QTILITY.
  (labels ((random-between (a b)
             "Generate a random integer between A and B, inclusive."
             (assert (>= b a))
             (if (= a b)
                 a
                 (+ a (random (- (1+ b) a)))))
           
           (nshuffle-vector (vector)
             "Destructively shuffle VECTOR randomly."
             (let ((n (length vector)))
               (loop :for i :below n 
                     :for r := (random-between i (1- n))
                     :when (/= i r)
                     :do (rotatef (aref vector i)
                                  (aref vector r))
                     :finally (return vector))))
           
           (shuffle (list)
             "Shuffle the list LIST randomly."
             (let ((vec (make-array (length list) :initial-contents list)))
               (concatenate 'list (nshuffle-vector vec)))))
    (dolist (s (shuffle strings) tree)
      (completion-tree-add tree s))))

(defun completion-tree-contains-p (tree str)
  "Check if TREE contains the word STR."
  (do ((pos 0)
       (node (completion-tree.root tree)))  
      ((null node))                     ; While NODE is not null...

    (cond
      ((char< (aref str pos)
              (completion-node.char node))
       (setf node (completion-node.left node)))
      
      ((char> (aref str pos)
              (completion-node.char node))
       (setf node (completion-node.right node)))
      
      (t (if (= (incf pos) (length str))
             (return-from completion-tree-contains-p (completion-node.endp node))
             (setf node (completion-node.middle node))))))
  
  nil)                                  ; Return NIL otherwise...

(defun completion-node-completions (node &key (prefix "")
                                              limit)
  "Walk the children of NODE to find all completions."
  (let ((completion-list nil)
        (completion-count 0))
    (labels ((compute-node-completions (node prefix)
               (when (and node (not (eql limit completion-count)))
                 (let* ((cstr (string (completion-node.char node)))
                        (prefix+cstr (concatenate 'string prefix cstr)))
                   (when (completion-node.endp node)
                     (push prefix+cstr completion-list)
                     (incf completion-count))
                   
                   (compute-node-completions (completion-node.left node)
                                             prefix)
                   (compute-node-completions (completion-node.middle node)
                                             prefix+cstr)
                   (compute-node-completions (completion-node.right node)
                                             prefix)))))
      (compute-node-completions node prefix)
      
      (nreverse completion-list))))

;;;;;;;;;;;;;;;;;; Traveling along completion nodes ;;;;;;;;;;;;;;;;;;

(defgeneric completion-node-travel (node item)
  (:documentation "Travel to the next node from NODE along the
  branch(es) specified by ITEM."))

(defmethod completion-node-travel ((node null) item)
  nil)

(defmethod completion-node-travel ((node completion-node) (item character))
  (cond
    ((null node) nil)
    
    ((char< item (completion-node.char node))
     (completion-node-travel (completion-node.left node) item))
    
    ((char> item (completion-node.char node))
     (completion-node-travel (completion-node.right node) item))
    
    (t (completion-node.middle node))))

(defmethod completion-node-travel ((node completion-node) (item list))
  (cond
    ((null item) node)
    ((null node) nil)
    (t (completion-node-travel (completion-node-travel node (car item))
                               (cdr item)))))

(defmethod completion-node-travel ((node completion-node) (item string))
  (completion-node-travel node (concatenate 'list item)))

;;;;;;;;;;;;;;;;;;;;;;; Completion computation ;;;;;;;;;;;;;;;;;;;;;;;

(defgeneric compute-completions (node item &key limit prefixedp)
  (:documentation "Compute the completions of of ITEM given a node or
  tree NODE. If an integer limit LIMIT is given, then only a maximum
  of LIMIT completions will be given. If PREFIXEDP is true, then the
  completions will include the prefix."))

(defmethod compute-completions ((node completion-node) item &key limit
                                                                 prefixedp)
  (completion-node-completions (completion-node-travel node item)
                               :limit limit
                               :prefix (and prefixedp (string item))))

(defmethod compute-completions ((tree completion-tree) item &key limit
                                                                 prefixedp)
  (completion-node-completions
   (completion-node-travel (completion-tree.root tree) item)
   :limit limit
   :prefix (and prefixedp (string item))))

