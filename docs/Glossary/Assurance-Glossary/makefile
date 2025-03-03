gloss-doc.pdf: *.tex ../glossary-Assurance.tex ../assurance-refs.bib ../Templates/LaTeX/gloss-doc.sty
	pdflatex gloss-doc
	bibtex gloss-doc
	makeglossaries gloss-doc
	pdflatex gloss-doc
	bibtex gloss-doc
	makeglossaries gloss-doc
	pdflatex gloss-doc
	bibtex gloss-doc
	makeglossaries gloss-doc
	pdflatex gloss-doc
	pdflatex gloss-doc
	pdflatex gloss-doc
clean:
	rm *.acn *.acr *alg *.aux *.bbl *.blg *.glg *.glo *.gls *.ist *.log *.out *.toc *.brf *.lof
