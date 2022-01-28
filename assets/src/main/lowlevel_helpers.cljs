(ns lowlevel-helpers)

(defn starts-with-pattern? [s pattern]
  (not (nil? (re-find (re-pattern (str "^" pattern)) s))))

(defn index-of-substr-or-end [s pattern]
  (loop [rst s
         i 0]
    (if (= i (count s))
      i
      (if-not (starts-with-pattern? rst pattern)
        (recur (apply str (rest rst)) (inc i))
        i))))

(defn reverse-state [{value           :value
                      selection-start :selection-start
                      selection-end   :selection-end}]
  {:value           (apply str (reverse value))
   :selection-start (- (count value) selection-start)
   :selection-end   (- (count value) selection-end)})

(defn leftwards [fun]
  (fn [state]
    (-> state reverse-state fun reverse-state)))

(defn calc-rest [{value :value selection-start :selection-start}]
  (subs value selection-start (count value)))