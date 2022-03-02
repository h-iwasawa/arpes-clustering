# Read me<br>
The codes in this repository are an additional materials for:<br>
**Unsupervised clustering for identifying spatial inhomogeneity on local electronic structures**<br>
Hideaki Iwasawa, Tetsuro Ueno, Takahiko Masui, Setsuko Tajima<br>
npj Quantum Materials 7, 24 (2022).<br>
[doi.org/10.1038/s41535-021-00407-5](https://doi.org/10.1038/s41535-021-00407-5)<br>
Correspondence should be addressed to H.I. (iwasawa.hideaki@qst.go.jp)<br>

- Codes are available as Jupyter Notebook (*.ipynb).
- Brief instructions are given in below.

## Contents in this repository
- Data : Two kinds of spatially-resolved ARPES mapping data 
- Part1 : Data Loading and pre-processing
- Part2 : k-means clustering
  - (2-1) Application
  - (2-2) Evaluation
- Part3 : Fuzzy-c-means clustering
  - (3-1) Application
  - (3-2) Evaluation
- Part4 : Principal Component Analysis

## Requried libraries
- Load data
  - nexusformat: https://pypi.org/project/nexusformat/
- Standard data handling and visualization
  - numpy: https://pypi.org/project/numpy/
  - matplotlib: https://pypi.org/project/matplotlib/
- K-means clustering
  - scikit-learn: https://pypi.org/project/scikit-learn/
  - gap_statistic: https://pypi.org/project/gap-stat/
- Fuzzy-c-means clustering
  - skfuzzy: https://pypi.org/project/scikit-fuzzy/

## Instructions
- **Check Input and Output Path**<br>
  Default settings<br>
    - Input path is placed in the same directry as the code files (jupyter notebooks). 
    - Output file will be stored in an "out" folder, which will be creacted in the same directry as the code files. 
- **Always run Part1 first** because Part2~4 require pre-processed dataset.<br>
- The below figure shows the flow of clustering analysis with typical time required for executing each analysis.<br>
  (analysis time will depend on you machine environment and parameter settings)<br>

![Overview](https://github.com/h-iwasawa/Test/blob/ca2a064f292d4c05d22ab5b21487c07f984c317c/arpes-clustering-overview.png)

## License
Copyright (c) 2021 Hideaki Iwasawa<br>
This "arpes-clustering" respository is released under the [MIT license](LICENSE).
