# (I2) Data Pre-processing
- Download a procedure file of "KM_clustering.ipf". 
- Compile it after launching the Igor Pro.
- Load your target data, as shown in the previous instruction (I1).

**NOTE**
<br>

Here, we will show the protocol for handling two types of mapping data.<br>
One type is composed of a single multi-dimensional (4D-2D) volume data.<br>
The other type is composed of a series of 2D ARPES or 1D slice (EDC or ADC) data.<br>
In this example, we will handle the Ba 4d mapping data, as loaded in (I1).<br>
For a series of data (Case 2), we used 2D ARPES datasets (1150 waves) decomposed from the 4D volume data.<br>

---
## Case 1: A volume data

### Start up
1. Set a red arrow to a folder containing the target data.<br>
2. Call a main control panel from Menu selection: "Macros" -> "k-means clustering" -> "Start".<br>
<img src="https://github.com/h-iwasawa/arpes-clustering/blob/7d25db2a284a04faff850abcef3b61a1c5342011/I2-1.png" width="300">

3. Select a map type and data type from each list.<br>
  - Map type
    - 4D: ARPES x 2D spatial map
    - 3D: ARPES x 1D spatial map
    - 3D: Slice x 2D spatial map
    - 2D: Slice x 1D spatial map
  - Data type
    - A volume data: mapping data is composed of a single data.
    - A series of data: mapping data is composed of multiple data.
<img src="https://github.com/h-iwasawa/arpes-clustering/blob/5c8ee789179ce98a6c26ea29a22dbd6b4c9f95c0/I2-2.png" width="300">

4. Select a target wave from the list.
  - Only waves having the same dimension specified by the Map type are listed.
  - The list referred to the current data folder.<br>
<img src="https://github.com/h-iwasawa/arpes-clustering/blob/5c8ee789179ce98a6c26ea29a22dbd6b4c9f95c0/I2-3.png" width="300">

5. After proceeding with the dialogs, the main control panel is popped up.<br>

<img src="https://github.com/h-iwasawa/arpes-clustering/blob/1fe48e9a444861af430923a36b84423ab34613fe/I2-4.png" width="600">

<details>
<summary>Details of panel's functions</summary>
&nbsp;&nbsp;&nbsp;&nbsp;(a) Popup menus for setting "Map type", "Data type", and "Target Data" or "Taget Data Folder".<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Once target data/data folder is selected, these settings will be updated.<br>
&nbsp;&nbsp;&nbsp;&nbsp;(b) Variable- and String-controls for setting axis scalings and units.<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Modifications of them do NOT directly overwrite the target data. -> "Update scaling" is needed.<br>
&nbsp;&nbsp;&nbsp;&nbsp;(c) Variables for setting integration window for making iEDC/iADC.<br>
&nbsp;&nbsp;&nbsp;&nbsp;(d) Popup menu for "Load scaling", "Update scaling", "Map range re-scaling", "Enegry calibration", "Transpose axis", and "Flatten data".<br>
&nbsp;&nbsp;&nbsp;&nbsp;(e) Button controls for "KM clustering", "Show clustering results", and "Show map viewer".<br>
</details>

---

### Data Pre-processing

1. Modify axis scalings by manual or semi-auto settings<br>
  - Manual Setting
    - Enter scaling values (start and delta) and Units of data axes in variable controls (b).
    - Select "Update scaling" from the popup menu (d), and push "OK" in a confirmation dialog if settings are fine.
  - Semi-Auto Setting
    - Select "Load scaling" from the popup menu (d).
    - Select an axis wave for each dimension and "Yes/No" whether calibrating mapping axes and energy scale.
      - Map axis calibration: Center of the mapping axes becomes zero.
      - Energy calibration: Rescaled with respect to the Fermi energy, specified in the subsequent dialog (bottom center).
    - Do "Update scaling", if settings are fine like at the right in the below figure.
<img src="https://github.com/h-iwasawa/arpes-clustering/blob/a259d5f115fae1e8737f4d4b2b246727fbea825b/I2-5.png" width="1000">

2. Transpose Axis
  - Select "Transpose Axis" from the popup menu (d). 
  - Select a proper mode from the list in the user dialog to match one of the settings shown in the below table.<br>
  - After pushing "Continue", the dimension order of the target wave and panel will be updated like at the right in the below figure.
<img src="https://github.com/h-iwasawa/arpes-clustering/blob/e81b72661702e98e4e2227e13d8d1343bb81de7f/I2-6.png" width="750">
<img src="https://github.com/h-iwasawa/arpes-clustering/blob/fdbc5d4b735da86c96acd99ce1bd06afaeff266b/I2-6.png" width="1000">

3. Flatten data
  - Select "Flatten data" from the popup menu (d). Then, iEDCs and iADCs will be created.
    - Integration windows are set as a full range in default.
    - They can also be changed by modifying variables of the "Integration Window" (c).

---
## Case 2: A series of data

The protocol for handling a series of data is essentially the same as one for the volume data shown above.<br>
Find below the itemized pictures and brief notes for instructions.<br>

<details>
<summary>Start up</summary>
<br>
1. All the seris of data should be stored in a single data folder.<br>
2. Call a main control panel from Menu selection: "Macros" -> "k-means clustering" -> "Start".<br>
3. Proceed User dialogs, as illustrated in the below gallery.<br>

<br><details>
<summary>Gallery: Prepare Data and Folder</summary>
<br><img src="https://github.com/h-iwasawa/arpes-clustering/blob/7db7a0a64e00bd585f25d5468a7b581db28bd2d0/I2-8.png" width="200">
</details>
 
<details>
<summary>Gallery: First dialog</summary>
<br><img src="https://github.com/h-iwasawa/arpes-clustering/blob/7db7a0a64e00bd585f25d5468a7b581db28bd2d0/I2-9.png" width="500">
</details>

<details>
<summary>Gallery: Panel called with map-range calibration</summary>
<br><img src="https://github.com/h-iwasawa/arpes-clustering/blob/7db7a0a64e00bd585f25d5468a7b581db28bd2d0/I2-10.png" width="1000">
</details>

<details>
<summary>Gallery: Panel called without map-range calibration</summary>
<br><img src="https://github.com/h-iwasawa/arpes-clustering/blob/7db7a0a64e00bd585f25d5468a7b581db28bd2d0/I2-11.png" width="1000">
</details>
  
</details>

---  

<details>
<summary>Data Pre-processing</summary>
<br>
Proceed "Update Scaling", "Map range re-scaling", "Energy calibration", and "Flatten data", as illustrated in the below gallery<br>

<br><details>
<summary>Gallery: Update Scaling</summary>
<br>Note: Update Axis Units.<br>
<br><img src="https://github.com/h-iwasawa/arpes-clustering/blob/7db7a0a64e00bd585f25d5468a7b581db28bd2d0/I2-12.png" width="1000">
</details>

  
<details>
<summary>Gallery: Map range re-scaling</summary>
<br>Note: Set the image center as zero using the number of points and delta.<br>
<br><img src="https://github.com/h-iwasawa/arpes-clustering/blob/7db7a0a64e00bd585f25d5468a7b581db28bd2d0/I2-13.png" width="1000">
</details>

<details>
<summary>Gallery: Energy calibration</summary>
<br>Note: Calibrate energy with respect to the input value for the Fermi energy.<br>
<br><img src="https://github.com/h-iwasawa/arpes-clustering/blob/7db7a0a64e00bd585f25d5468a7b581db28bd2d0/I2-14.png" width="1000">
</details>

<details>
<summary>Gallery: Flatten data</summary>
<br>Note: Run from the popup menu. Then, iEDCs and iADCs will be created.<br>
<br><img src="https://github.com/h-iwasawa/arpes-clustering/blob/7db7a0a64e00bd585f25d5468a7b581db28bd2d0/I2-15.png" width="500">
</details>
  
</details>
