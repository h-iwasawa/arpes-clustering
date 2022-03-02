# (I1) Load Data
We assume that many users already have their own macros for loading data.<br>
We thus do not include a package for loading data.<br>
However, we give instructions to load nexus data (.nxs) using a native Igor function for loading example datasets.

## Protocol
1. Menu Action<br>
- Open a "New HDF5 Browser" (Data -> Load Waves -> New HDF 5 Browser).
<details>
<summary>NOTE</summary>
In Igor 9, "New HDF5 Browser" can be used in default. Otherwise, do the followings.<br>
(1) Find a "HDF5 Browser.ipf" file in your Igor Program folder (Wavemetrics>Igor Pro 8/7 Folder).<br>
(2) Place the file (or its shortcut) in a "Igor Procedure" folder.
</details>
<img src="https://github.com/h-iwasawa/arpes-clustering/blob/0c7ac4bfedcdb8f6e3eb543b13d5fab4650acdc1/I1-1.png" width="300">

---
2. Button Action<br>
- "Open HDF file" on the New HDF5 Browser.
- Then, select a target file in an "Open HDF5 File" dialog, where you may need to change a file type to "All Files \*.\*"
<img src="https://github.com/h-iwasawa/arpes-clustering/blob/e53640020f90c5914778fc156d5a268898130d2b/I1-2.png" width="1000">

---
3. Button Action<br>
- Load Data by pushing “Load Group” or “Load Dataset” on the New HDF5 Browser.<br> 
  - The former loads datasets included in a Group selected on the left-hand side.<br>
  - The latter loads a selected Dataset on the right-hand side.<br>
- For subsequent analysis, it would be useful to load scaling information of data axes, such as energy, angle, and mapping axes.<br>
<img src="https://github.com/h-iwasawa/arpes-clustering/blob/cce311186abee8bf55aaf4c74800b51a1396d31c/I1-3.png" width="800">

---
3. Small preparations for subsequent analysis.
- For easy discrimination, rename waves and store them into a folder by creating a data folder, as shown below.
- Here, it is better to uncheck "Plot" in the "Data Browser" when handling a 4D wave.
- Note that you don't need to set the axis scaling information at present.<br> 
<img src="https://github.com/h-iwasawa/arpes-clustering/blob/e81213e675f07caf77f580d898b315edb572811e/I1-4.png" width="800">
(Left) and (center) Just after loading group or datasets by "Loading Group" or "Load Dataset" button, respectively.<br>
(Right) After renaming and storing files into a newly created data folder.
