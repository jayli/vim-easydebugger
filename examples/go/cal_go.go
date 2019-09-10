package main

import "fmt"
import "time"

func main() {
	t1 := time.Now()
	count := int64(0)
	max := int64(900)
	for i := int64(0); i < max; i++ {
		count += i
	}
	t2 := time.Now()
	fmt.Printf("cost:%d,count:%d\n", t2.Sub(t1)/1000000000, count)

}
