

.PHONY test: 
	prove --exec perl6 -lr

.PHONY git:
	git add .
	git commit 
	git push origin master

