;; TCO Verification and Benchmark Suite

(println "========================================")
(println "       newLISP Neo TCO Benchmark        ")
(println "========================================")

;; 1. Self-tail recursion test (100,000,000 steps)
(define (count-down n)
  (if (<= n 0)
      "done"
      (count-down (- n 1))))

(println "1. Testing Self-Tail Recursion (100,000,000 steps)...")
(set 't0 (time-of-day))
(set 'res1 (count-down 100000000))
(set 't1 (time-of-day))
(println "   Result: " res1)
(println "   Time: " (- t1 t0) " ms")

;; 2. Self-tail recursion accumulator (sum 1 to 10,000,000)
(define (sum-acc n acc)
  (if (<= n 0)
      acc
      (sum-acc (- n 1) (+ acc n))))

(println "2. Testing Tail Recursion Accumulator (10,000,000 steps)...")
(set 't0 (time-of-day))
(set 'res2 (sum-acc 10000000 0))
(set 't1 (time-of-day))
(println "   Result: " res2)
(println "   Expected: " 50000005000000)
(println "   Passed: " (= res2 50000005000000))
(println "   Time: " (- t1 t0) " ms")

;; 3. Mutual tail recursion test (10,000,000 steps)
(define (my-even? n)
  (if (= n 0)
      true
      (my-odd? (- n 1))))

(define (my-odd? n)
  (if (= n 0)
      nil
      (my-even? (- n 1))))

(println "3. Testing Mutual Tail Recursion (10,000,000 steps)...")
(set 't0 (time-of-day))
(set 'res3 (my-even? 10000000))
(set 't1 (time-of-day))
(println "   Result: " res3)
(println "   Passed: " (= res3 true))
(println "   Time: " (- t1 t0) " ms")

;; 4. Tail call inside cond
(define (cond-tail n)
  (cond
    ((<= n 0) 42)
    (true (cond-tail (- n 1)))))

(println "4. Testing Tail Call in cond (1,000,000 steps)...")
(set 't0 (time-of-day))
(set 'res4 (cond-tail 1000000))
(set 't1 (time-of-day))
(println "   Result: " res4)
(println "   Passed: " (= res4 42))
(println "   Time: " (- t1 t0) " ms")

;; 5. Tail call inside let / local
(define (let-tail n)
  (if (<= n 0)
      99
      (let (next-n (- n 1))
        (let-tail next-n))))

(println "5. Testing Tail Call in let (1,000,000 steps)...")
(set 't0 (time-of-day))
(set 'res5 (let-tail 1000000))
(set 't1 (time-of-day))
(println "   Result: " res5)
(println "   Passed: " (= res5 99))
(println "   Time: " (- t1 t0) " ms")

;; 6. Tail call inside begin
(define (begin-tail n)
  (if (<= n 0)
      777
      (begin
        (set 'dummy 1)
        (begin-tail (- n 1)))))

(println "6. Testing Tail Call in begin (1,000,000 steps)...")
(set 't0 (time-of-day))
(set 'res6 (begin-tail 1000000))
(set 't1 (time-of-day))
(println "   Result: " res6)
(println "   Passed: " (= res6 777))
(println "   Time: " (- t1 t0) " ms")

(println "========================================")
(println "   ALL TCO BENCHMARKS COMPLETED!        ")
(println "========================================")
(exit 0)
