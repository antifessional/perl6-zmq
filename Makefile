
.PHONY: test git github clean

test: 
	prove --exec perl6 -lr

git:
	git add .
	git commit 
	git push origin master

github: git
	git push github master

clean:
	rm -rf lib/.precomp

