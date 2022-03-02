# k-means clustering in Igor Pro<br>
The igor procedure file (KM_clustering.ipf) is an additional material for:<br>
**Unsupervised clustering for identifying spatial inhomogeneity on local electronic structures**<br>
Hideaki Iwasawa, Tetsuro Ueno, Takahiko Masui, Setsuko Tajima<br>
npj Quantum Materials 7, 24 (2022).<br>
[doi.org/10.1038/s41535-021-00407-5](https://doi.org/10.1038/s41535-021-00407-5)<br>
Correspondence should be addressed to H.I. (iwasawa.hideaki@qst.go.jp)<br>

## Requirements
The procedure file was coded and tested by using only Igor Pro 9.<br>
The operation using the older version of Igor Pro can not be guaranteed, though it might work.<br>
It is **necessary** to use **64 bit version** to handle large volume size of data.

## Overview
The procedure file handles ARPES (PES) mapping data after loading in Igor Pro.<br>
<br>
We assumes the type of mapping data as <br>
(a) A single data (3D-4D volume data / 2D image),<br>
(b) A series of data composed of multiple 1D waves or 2D images.<br>
<br>
The below figure shows a flow of the clustering analysis,<br>
which is mainly composed of three steps as (Step 1) Data Loading, (Step 2) Data Pre-processing, and (Step 3) k-means clustering.<br>
Those instructions (I1)-(I3) are available in this reposiotory.<br>

![Overview_KM_Igor](https://github.com/h-iwasawa/Test/blob/7b385889bd78dd4f2abf867ac7c1dadec6b84a71/KM_igor_overview.png)
