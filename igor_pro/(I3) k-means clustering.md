# (I3) k-means clustering

## Protocol

### k-means clustering
- Start by pushing "KM clustering" button.

---

- User dialog (1) : Basic clustering settings
  - Select target:
    - iEDC
    - iADC
  - Set maximum number of clusters.
  - Select whether modifying detailed settings:
    - Yes -> User dialog (2)
    - No (default) -> User dialog (3)

**NOTE: For beginners, use default settings without detailed settings.**

<img src="https://github.com/h-iwasawa/arpes-clustering/blob/943a3ddeb59622953fe8553dae6cec2335f00861/I3-1.png" width="300">

---

- User dialog (2) : Detailed clustering settings
  - Select how to handle dead classes:
    - Keep the last value of the mean vector (default)
    - Remove the dead class
    - Assign the class a random mean vector
  - Distance mode (only two modes are available):
    - Euclidian distance (default)
    - Manhattan distance
  - Initialization method
    - Initialize classes using randomly selected values from the population (default)
    - Random member-assignment to a class
  - Number of stop iterations (Set "-1" for iterating until results unchanged)

**NOTE: For details, see "helps" for a function of "KMeans" in Igor Help Browser.**

<img src="https://github.com/h-iwasawa/arpes-clustering/blob/943a3ddeb59622953fe8553dae6cec2335f00861/I3-2.png" width="300">

---

- User dialog (3): Spatial mapping settings
  - Confirm whether the mapping settings are fine.

**NOTE: Typically, this step is just for a double-check.**

<img src="https://github.com/h-iwasawa/arpes-clustering/blob/943a3ddeb59622953fe8553dae6cec2335f00861/I3-3.png" width="300">

---

- User dialog (4): Results visualization
  - Select whether visualize results or not:
    - Yes -> Set below settings
    - No -> Ignore below settings
  - Set a vertical position for graphs: 
    - Mode 0, 1 (default), 2, 3
    - ex.) Use Mode 1 and 2 for iEDC and iADC, respectively 
  - Select image's and wave's color.
  - Select whether reverse the color scale or not.
<img src="https://github.com/h-iwasawa/arpes-clustering/blob/0084ed488102c056359a46c4f64f9cbbf1f37e7f/I3-4.png" width="300">

**NOTE: "Show clustering results" button can also be used for visualization once KM clustering was performed.**

---
### Visualization
- k-means clustering should be performed in advance.

**Clustering results: iEDC case**
- Push "Show clustering results" button, or re-start from "k-means clustering" button.
<img src="https://github.com/h-iwasawa/arpes-clustering/blob/40f15a64ef7d19f9452aa6f0f4e4694fa8ae65b8/I3-5.png" width="1000">

**Clustering results with spatial mapping viewer: iEDC case**
- Push "Show Map Viewer" button.
- By moving a cursor in the upper graph window, the lower graph window will be updated to display ARPES spectra, iEDC and iADC at a cursor point. 
<img src="https://github.com/h-iwasawa/arpes-clustering/blob/40f15a64ef7d19f9452aa6f0f4e4694fa8ae65b8/I3-6.png" width="500">
