#lang racket/base

;;;    *************************************    ;;;
;;;    ***   Inotify - Racket Bindings   ***    ;;;
;;;    *************************************    ;;;

;;; author (FFI): Laurent orseau <laurent orseau gmail com> - 2013-01-04

(require "errno-base.rkt"
         x11-racket/fd
         ; go to your racket project directory and do:
         ; git clone http://github.com/kazzmir/x11-racket.git
         ; raco link x11-racket
         ; raco setup x11-racket
         ffi/unsafe
         ffi/unsafe/define
         racket/class
         racket/port
         racket/dict
         )

(provide (all-defined-out))

#| 

** Resources **

Documentation of the C API:
http://linux.die.net/man/7/inotify

See also pyinotify: 
http://seb-m.github.com/pyinotify/pyinotify.WatchManager-class.html#add_watch

** Description **

The inotify API provides a mechanism for monitoring file system events. 
Inotify can be used to monitor individual files, or to monitor directories.
When a directory is monitored, inotify will return events for the directory 
itself, and for files inside the directory. 

** Limitations and caveats (from the C docs) **

Inotify monitoring of directories is not recursive: to monitor 
subdirectories under a directory, additional watches must be created. 
This can take a significant amount time for large directory trees.

The inotify API provides no information about the user or process that 
triggered the inotify event.

Note that the event queue can overflow. In this case, events are lost.
Robust applications should handle the possibility of lost events gracefully.

The inotify API identifies affected files by filename. However, by the time
an application processes an inotify event, the filename may already have
been deleted or renamed.

If monitoring an entire directory subtree, and a new subdirectory is created
in that tree, be aware that by the time you create a watch for the new 
subdirectory, new files may already have been created in the subdirectory.
Therefore, you may want to scan the contents of the subdirectory immediately
after adding the watch. 

|#

;=================;
;=== C API FFI ===;
;=================;

(define-ffi-definer define-inotify (ffi-lib #f))

(define _flags
  (_bitmask
   '(IN_CLOEXEC  = 02000000
     IN_NONBLOCK =    04000)))

(define _mask
  (_bitmask
   '(NONE              = #x00000000  ; For default value
     IN_ACCESS         = #x00000001  ; File was accessed.
     IN_MODIFY         = #x00000002  ; File was modified.
     IN_ATTRIB         = #x00000004  ; Metadata changed, e.g., permissions, timestamps, extended attributes, link count (since Linux 2.6.25), UID, GID, etc
     IN_CLOSE_WRITE    = #x00000008  ; Writtable file was closed.
     IN_CLOSE_NOWRITE  = #x00000010  ; Unwrittable file closed.
     IN_CLOSE          = #x00000018  ; (IN_CLOSE_WRITE | IN_CLOSE_NOWRITE) ; Close.
     IN_OPEN           = #x00000020  ; File was opened.
     IN_MOVED_FROM     = #x00000040  ; File was moved from X.
     IN_MOVED_TO       = #x00000080  ; File was moved to Y.
     IN_MOVE           = #x000000c0  ; (IN_MOVED_FROM | IN_MOVED_TO) ; Moves.
     IN_CREATE         = #x00000100  ; Subfile was created.
     IN_DELETE         = #x00000200  ; Subfile was deleted.
     IN_DELETE_SELF    = #x00000400  ; Self was deleted.
     IN_MOVE_SELF      = #x00000800  ; Self was moved.
     ; Events sent by the kernel
     IN_UNMOUNT        = #x00002000  ; Backing fs was unmounted.
     IN_Q_OVERFLOW     = #x00004000  ; Event queued overflowed.
     IN_IGNORED        = #x00008000  ; File was ignored.
     ; Special flags
     IN_ONLYDIR        = #x01000000  ; Only watch the path if it is a directory
     IN_DONT_FOLLOW    = #x02000000  ; Do not follow a sym link
     IN_EXCL_UNLINK    = #x04000000  ; Exclude events on unlinked objects
     IN_MASK_ADD       = #x20000000  ; Add to the mask of an already existing watch
     IN_ISDIR          = #x40000000  ; Event occurred against dir.
     IN_ONESHOT        = #x80000000  ; Only send event once.
     )
   _uint32))
     
; All events which a program can wait on
(define IN_ALL_EVENTS  
  '(IN_ACCESS IN_MODIFY  IN_ATTRIB  IN_CLOSE_WRITE  
              IN_CLOSE_NOWRITE  IN_OPEN  IN_MOVED_FROM	      
              IN_MOVED_TO  IN_CREATE  IN_DELETE		      
              IN_DELETE_SELF  IN_MOVE_SELF))
  
(define-cstruct _inotify_event
  ((wd      _int)      ; Watch descriptor
   (mask    _mask)     ; Mask of events
   (cookie  _uint32)   ; Unique cookie associating related events (for `rename')
                       ; allows the resulting pair of IN_MOVE_FROM and IN_MOVE_TO 
                       ; events to be connected by the application.
   (len     _uint32)   ; Size of the name field
   ; Don't add the name, it will be read separately!
   ;(name    _pointer)  ; (char*) Optional null-terminated name
   ))

(define (make-inotify-empty-event)
  (make-inotify_event 0 'NONE 0 0 #;#f))

(define (inotify-init-errno funsym)
  (error funsym
   (format-errsym
    '((EINVAL . "An invalid value was specified in flags")
      (EMFILE . "The user limit on the total number of inotify instances has been reached")
      (ENFILE . "The system limit on the total number of file descriptors has been reached")
      (ENOMEM . "Insufficient kernel memory is available")))))

;/* Create and initialize inotify instance.  */
;extern int inotify_init (void) __THROW;
;; On success, these system calls return a new file descriptor. 
;; On error, -1 is returned, and errno is set to indicate the error. 
(define-inotify inotify_init 
  (_fun -> (fd : _int)
        -> (if (= fd -1)
               (inotify-init-errno 'inotify_init)
               fd
               )))

;/* Create and initialize inotify instance.  */
;extern int inotify_init1 (int __flags) __THROW;
;; See inotify_init
(define-inotify inotify_init1 
  (_fun _flags 
        -> (fd : _int)
        -> (if (= fd -1)
               (inotify-init-errno 'inotify_init1)
               fd)))

;/* Add watch of object NAME to inotify instance FD.  Notify about events specified by MASK.  */
;extern int inotify_add_watch (int __fd, const char *__name, uint32_t __mask) __THROW;
;; On success, inotify_add_watch() returns a nonnegative watch descriptor. 
;; On error -1 is returned and errno is set appropriately. 
(define-inotify inotify_add_watch 
  (_fun _int _string _mask 
        -> (wd : _int)
        -> (if (= wd -1)
               (error 'inotify_add_watch
                      (format-errsym
                       '((EACCES . "Read access to the given file is not permitted")
                         (EBADF  . "The given file descriptor is not valid")
                         (EFAULT . "pathname points outside of the process's accessible address space")
                         (EINVAL . "The given event mask contains no valid events; or fd is not an inotify file descriptor")
                         (ENOENT . "A directory component in pathname does not exist or is a dangling symbolic link")
                         (ENOMEM . "Insufficient kernel memory was available")
                         (ENOSPC . "The user limit on the total number of inotify watches was reached or the kernel failed to allocate a needed resource"))))
               wd)))

;/* Remove the watch specified by WD from the inotify instance FD.  */
;extern int inotify_rm_watch (int __fd, int __wd) __THROW;
;; On success, inotify_rm_watch() returns zero, 
;; or -1 if an error occurred (in which case, errno is set appropriately). 
(define-inotify inotify_rm_watch 
  (_fun _int _int 
        -> (res : _int)
        -> (if (= res -1)
               (error 'inotify_rm_watch
                      (format-errsym
                       '((EBADF  . "fd is not a valid file descriptor")
                         (EINVAL . "The watch descriptor wd is not valid; or fd is not an inotify file descriptor"))))
               #t)))

;=================;
;=== Interface ===;
;=================;

(module+ test
  (require rackunit)
  (displayln "Tests"))

;; Converts the bytes to a string, like bytes->string/locale
;; but omits the null bytes at the end of the byte string.
;; bytes? -> string?
(define (null-terminated-bytes->string/locale b)
  (define len
    (or
     (for/or ([i (in-range (bytes-length b) 0 -1)])
       (and (not (= 0 (bytes-ref b (sub1 i))))
            i))
     0))
  (bytes->string/locale b #f 0 len))

(module+ test
  (let ([proc null-terminated-bytes->string/locale])
    (check-equal? "A" (proc (bytes 65 0 0)))
    (check-equal? "ABC" (proc (bytes 65 66 67)))
    (check-equal? "ABC" (proc (bytes 65 66 67 0)))
    (check-equal? "ABC" (proc (bytes 65 66 67 0 0)))
    (check-equal? "" (proc (bytes)))
    (check-equal? "" (proc (bytes 0)))
    ))

(define inotify%
  (class object%
    (super-new)
    (init-field callback)
    ;; callback: (path-string? (or/c string? #f) (listof symbol?) . -> . any)
    (field [watches '()]
           [fd #f]
           [in #f]
           [read-thread #f])
    
    (define ev (make-inotify-empty-event))
    (define ev-bytes (make-sized-byte-string ev (ctype-sizeof _inotify_event)))

    (define/public (init)
      (set! fd (inotify_init)))
    (init)
    
    (define (find-watch-descriptor watch)
      (define elt (findf (λ(p)(equal? watch (cdr p))) watches))
      (and elt (car elt)))
    
    (define (add-watch-base dir mask)
      (printf "Adding watch to: ~a ~a\n" dir mask)
      (define wd (inotify_add_watch fd dir mask))
      (set! watches (cons (cons wd dir) watches))
      )
    
    ;; follow-links? : if #f, for sub-directories that are sym-links,
    ;;   do not add a directory watch.
    ;; TODO: 
    ;;  - auto-add: when a directory is created in a watched dir, auto-watch it
    ;;  - add inclusion/exclusion pattern lists (for directories)
    (define/public (add-watch path mask [recursive? #f]
                              #:follow-links? [follow-links? #t])
      (unless (path-string? path)
        (raise-argument-error 'add-watch "path-string?" path))
      (add-watch-base path mask)
      (when (and recursive? (directory-exists? path))
        (for ([d (in-directory path)])
          (when (and (directory-exists? d)
                     (or follow-links? (not (link-exists? d))))
            (printf "Adding recursive watch: ~a\n" d)
            (add-watch-base d mask)
            )))
      )
    
    (define/public (remove-watch watch) 
      (define wd (find-watch-descriptor watch))
      (if wd
          (begin (inotify_rm_watch fd wd)
                 (set! watches (dict-remove watches wd)))
          (error 'remove-watch "Watch descriptor not found for" watch)))
    
    (define/public (remove-all-watches)
      (for ([wd (in-dict-keys watches)])
        (inotify_rm_watch fd wd))
      (set! watches '()))

    (define/public (start) 
      (set! in (open-fd-input-port fd))
      (set! read-thread
        (thread
         (λ()
           (let loop ()
             (sync/enable-break
              (handle-evt (read-bytes!-evt ev-bytes in)
                          (lambda (_fd)
                            (print (list _fd ev-bytes))
                            (newline)
                            (displayln (inotify_event->list* ev))
                            (define len (inotify_event-len ev))
                            (define name #f)
                            (when (> len 0)
                              (set! name (null-terminated-bytes->string/locale (read-bytes len in))))
                            (print (list 'name name))
                            (newline)
                            
                            (define watch (dict-ref watches (inotify_event-wd ev)))
                            (define mask (inotify_event-mask ev))
                            (callback watch name mask)
                            (loop)))
              (handle-evt (port-closed-evt in)
                          (λ(_a)(displayln "Port closed.")))))
           (displayln "Thread ended.")))))
    
    (define/public (stop-and-close) 
      (when in
        ;(remove-all-watches) ; no need: done automatically when closing the port, which closes the file descriptor
        ; This also automatically ends the thread
        (close-input-port in)
        (set! in #f)
        ))
    ))

;; TESTS
(module+ main
  (require racket/file)
  
  (define dir (make-temporary-file "rkttmp~a" 'directory))
  
  (define inotify (new inotify% 
                       [callback (λ(watch name mask)
                                   (displayln (list watch name mask)))]))
  (send inotify add-watch dir '(IN_MODIFY IN_CREATE IN_DELETE IN_MOVED_FROM IN_MOVED_TO) #t)
  (send inotify start)
  (displayln "inotify started. You may now make modifications in the specified directory.")
  
  ; Then go to directory dir in a terminal and do the following:
  ; $ touch 1.txt
  ; $ rm 1.txt
  ; $ touch 2.txt
  ; $ mv 2.txt 3.txt
  ; You should then see a sequence of IN_CREATE, IN_DELETE, IN_CREATE, IN_MOVED_FROM, 
  ; and IN_MOVED_TO events.
  
  (displayln "Enter something to end the program.")
  (read-line)
  (send inotify stop-and-close)
  )
