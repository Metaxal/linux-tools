#lang racket/base

;;;    ****************************    ;;;
;;;    ***   Errno - For Ffis   ***    ;;;
;;;    ****************************    ;;;

;;; author (FFI): Laurent orseau <laurent orseau gmail com> - 2013-01-04

(require ffi/unsafe
         (only-in '#%foreign ctype-c->scheme ctype-scheme->c)
         racket/dict)

(provide (all-defined-out))

(define errno (get-ffi-obj "errno" #f _int))

(define _errno
  (_enum 
   '(EPERM    = 1
     ENOENT   = 2
     ESRCH    = 3
     EINTR    = 4
     EIO      = 5
     ENXIO    = 6
     E2BIG    = 7
     ENOEXEC  = 8
     EBADF    = 9
     ECHILD   = 10
     EAGAIN   = 11
     ENOMEM   = 12
     EACCES   = 13
     EFAULT   = 14
     ENOTBLK  = 15
     EBUSY    = 16
     EEXIST   = 17
     EXDEV    = 18
     ENODEV   = 19
     ENOTDIR  = 20
     EISDIR   = 21
     EINVAL   = 22
     ENFILE   = 23
     EMFILE   = 24
     ENOTTY   = 25
     ETXTBSY  = 26
     EFBIG    = 27
     ENOSPC   = 28
     ESPIPE   = 29
     EROFS    = 30
     EMLINK   = 31
     EPIPE    = 32
     EDOM     = 33
     ERANGE   = 34
     )))

(define (errsym->errno sym)
  ((ctype-scheme->c _errno) sym))

(define (errno->errsym n)
  ((ctype-c->scheme _errno) n))

;; Returns an error string corresponding to the error
;; An additional dictionary of (errsym . string) can be given 
;; which is used in priority. If the errsym is not found in the
;; dictionary, it is looked up in the default one.
;; (see inotify.rkt for some examples)
(define (errsym->string sym [dict '()])
  (let ([no (errsym->errno sym)])
    (format "Error ~a (~a): ~a" no sym
            (dict-ref dict sym
                      (λ()(case sym
                            [(EPERM)    "Operation not permitted"]
                            [(ENOENT)   "No such file or directory"]
                            [(ESRCH)    "No such process"]
                            [(EINTR)    "Interrupted system call"]
                            [(EIO)      "I/O error"]
                            [(ENXIO)    "No such device or address"]
                            [(E2BIG)    "Argument list too long"]
                            [(ENOEXEC)  "Exec format error"]
                            [(EBADF)    "Bad file number"]
                            [(ECHILD)   "No child processes"]
                            [(EAGAIN)   "Try again"]
                            [(ENOMEM)   "Out of memory"]
                            [(EACCES)   "Permission denied"]
                            [(EFAULT)   "Bad address"]
                            [(ENOTBLK)  "Block device required"]
                            [(EBUSY)    "Device or resource busy"]
                            [(EEXIST)   "File exists"]
                            [(EXDEV)    "Cross-device link"]
                            [(ENODEV)   "No such device"]
                            [(ENOTDIR)  "Not a directory"]
                            [(EISDIR)   "Is a directory"]
                            [(EINVAL)   "Invalid argument"]
                            [(ENFILE)   "File table overflow"]
                            [(EMFILE)   "Too many open files"]
                            [(ENOTTY)   "Not a typewriter"]
                            [(ETXTBSY)  "Text file busy"]
                            [(EFBIG)    "File too large"]
                            [(ENOSPC)   "No space left on device"]
                            [(ESPIPE)   "Illegal seek"]
                            [(EROFS)    "Read-only file system"]
                            [(EMLINK)   "Too many links"]
                            [(EPIPE)    "Broken pipe"]
                            [(EDOM)     "Math argument out of domain of func"]
                            [(ERANGE)   "Math result not representable"]
                            ))))))

(define (format-errsym [dict '()])
  (errsym->string (errno->errsym errno) dict))

