(define (loop-test n)
  (let (s 0 i 0)
    (while (< i n)
      (set 's (+ s i))
      (set 'i (+ i 1)))
    s))

(println "--- 1. Iterative While Loop ---")
(println "Warmup: " (loop-test 1000))
(set 't0 (time (set 'res (loop-test 1000000))))
(println "Result: " res)
(println "Time: " t0 " ms\n")

;; Tail-recursive loop (TCO)
(define (loop-tco-acc n s i)
  (if (< i n)
      (loop-tco-acc n (+ s i) (+ i 1))
      s))

(define (loop-tco n)
  (loop-tco-acc n 0 0))

(println "--- 2. Tail-Recursive Loop (TCO) ---")
(println "Warmup: " (loop-tco 1000))
(set 't1 (time (set 'res2 (loop-tco 1000000))))
(println "Result: " res2)
(println "Time: " t1 " ms")
(exit)

