#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
  
// k-means clustering in Igor Pro
//
// The igor procedure file (KM_clustering.ipf) is an additional material for:
// Unsupervised clustering for identifying spatial inhomogeneity on local electronic structures
// Hideaki Iwasawa, Tetsuro Ueno, Takahiko Masui, Setsuko Tajima
// npj Quantum Materials (2021).
// DOI: 10.1038/s41535-021-00407-5
// Correspondence should be addressed to H.I. (iwasawa.hideaki@qst.go.jp)
//
// Copyright (c) 2021 Hideaki Iwasawa 
// This program is released under the MIT license.
//
// Note add //
// Users of this program shall use this program at their own responsibility.
// We do not hold any responsibility for any problems for output results, or unexpected losses or damages to user's data.
// Please always consider whether output is physically meaningful or not.
// In particular, output results often depend on S/N ratio and/or features of data.
//
// Visit the repository for instructions
// https://github.com/h-iwasawa/arpes-clustering

Menu "Macros"
	Submenu "k-means clustering"
		"Start", km_start()
		"Call Panel", km_call_panel()
		"-"
		"(Panel menus"
		"Load scaling from waves", kmp_load_scales()
		"Update scaling", kmp_set_scales()
		"Map range re-scaling", kmp_map_clb()
		"Transpose axis", kmp_transpose_Dimension()
		"Flatten data", kmp_flatten_data()
		"KM clustering", kmp_km_clustering()
		"Show clustering results", kmp_visualize_results()
		"Show Map Viewer", kmp_map_simple_viewer(); kmp_mv_pntdata_viewer()
	end
End
 
strconstant kmwd_prep = "root:KM_clustering_prep"			// working directory, where data pre-processing will be done
strconstant kmwd_res = "root:KM_clustering_results"			// working directory, where results of k-means clustering will be stored
strconstant kmwd_view = "root:KM_clustering_results:Viewer"	// working directory for mapping viewer

///////////////////////////////////////////////////////////////

Function km_start() // data preparation for km clustering
	kmp_ini()	
	km_call_panel()
End

Function kmp_ini([tarwv, tardf]) // or can be used to update value by specifying tarwv
	Wave tarwv
	String tardf
	//
	DFREF cdfr = GetDAtaFolderDFR()
	//
	NewDataFolder/O/S $kmwd_prep
	//
	If(ParamIsDefault(tarwv) && ParamIsDefault(tardf))
		Variable v1, v2
		Prompt v1, "Select Map type", popup "4D : ARPES 2D spatial map;3D : ARPES 1D spatial map;3D : Slice 2D spatial map;2D : Slice 1D spatial map"
		Prompt v2, "Select Data type", popup "A volume data;A series of data"
		DoPrompt "Calling KM-clustering's control panel : Map & Data type", v1, v2
		If(V_Flag)
			cd cdfr
			Abort
		Endif
		//
		Variable/G maptype = v1, datatype = v2, ismapbidir = 0
		
		String wvstr, wvlist, fdstr
		Variable mapclb
		switch(datatype)
			case 1:
				cd cdfr
				wvlist = WaveList("*", ";", "DIMS:4")+","+WaveList("*", ";", "DIMS:3")+","+WaveList("*", ";", "DIMS:3")+","+WaveList("*", ";", "DIMS:2")
				Prompt wvstr, "Select Target Data", popup StringFromList(maptype-1, wvlist, ",")
				DoPrompt "Calling KM-clustering's control panel : Data Setting", wvstr
				If(V_Flag)
					cd cdfr
					Abort
				Endif
				//
				Wave tarwv = $wvstr
			break
			case 2:
				wvstr = "New_SPmap"
				Prompt wvstr, "Name of creating volume wave"
				Prompt fdstr, "Select Target Data Folder", popup kmp_fdlist()
				Prompt mapclb, "Calibrate mapping scaling w.r.t. Center?", popup "Yes;No"
				DoPrompt "Calling KM-clustering's control panel : Data Setting", wvstr, fdstr, mapclb
				If(V_Flag)
					cd cdfr
					Abort
				Endif
				//
				Wave tarwv = kmp_combine_waves(fdstr, wvstr, mapclb)
			break
		endswitch
	Endif
	
	cd $kmwd_prep
	Nvar maptype
	// All required variables are included in two waves
	Make/O/D/N=(4, 4) $"Waves_Scaling"/Wave = wswv
	Make/O/T/N=(4) $"Waves_Unit"/Wave = wuwv
	
	// Load scaling
	String/G wvpath = GetWavesDataFolder(tarwv, 2)
	Variable/G wvdim = WaveDims(tarwv)
	Variable/G da1_r1, da1_r2, da2_r1, da2_r2
	Variable/G da1_r1pnt, da1_r2pnt, da2_r1pnt, da2_r2pnt
	Variable da1_sta = DimOffset(tarwv, 0), da1_del = DimDelta(tarwv, 0), da1_size = DimSize(tarwv, 0)
	Variable da2_sta = DimOffset(tarwv, 1), da2_del = DimDelta(tarwv, 1), da2_size = DimSize(tarwv, 1)
	//
	if(maptype <= 2)
		da1_r1 = da1_sta; da1_r2 = da1_sta + da1_del * (da1_size-1)
		da2_r1 = da2_sta; da2_r2 = da2_sta + da2_del * (da2_size-1)
		//
		da1_r1pnt = 0; da1_r2pnt = da1_size-1
		da2_r1pnt = 0; da2_r2pnt = da2_size-1
	else
		da1_r1 = da1_sta; da1_r2 = da1_sta + da1_del * (da1_size-1)
		da1_r1pnt = 0; da1_r2pnt = da1_size-1
	endif
	
	Variable i
	for(i=0; i<4; i+=1)
		if(i < wvdim)
			wswv[i][0] = DimSize(tarwv, i)
			wswv[i][1] = DimOffset(tarwv, i)
			wswv[i][2] = DimDelta(tarwv, i)
			wswv[i][3] = wswv[i][1] + wswv[i][2] * (wswv[i][0]-1)
			wuwv[i] = WaveUnits(tarwv, i)
		else
			wswv[i][0] = NaN
			wswv[i][1] = NaN
			wswv[i][2] = NaN
			wswv[i][3] = NaN
			wuwv[i] = "N/A"
		endif
	endfor
	
	If(WinType("kmp_win") != 0)
		KillWindow/Z kmp_win
		km_call_panel() 
	Endif
	//
	cd cdfr
End

Function/Wave kmp_combine_waves(fdstr, wvstr, mapclb)
	String fdstr, wvstr
	Variable mapclb
	//	
	DFREF cdfr = GetDAtaFolderDFR()
	//
	cd $kmwd_prep
		Nvar maptype
		String/G fdpath = fdstr
	cd $fdstr
		String fullwvlist = WaveList("*", ";", "DIMS:2")+","+WaveList("*", ";", "DIMS:2")+","+WaveList("*", ";", "DIMS:1")+","+WaveList("*", ";", "DIMS:1")
		String tarwvlist = StringFromList(maptype-1, fullwvlist, ",")
		Wave refwv = $StringFromList(0, tarwvlist) // Assume same scaling
		//
		Variable n = ItemsInList(tarwvlist)
		Variable i1 = DimOffset(refwv, 0), d1 = DimDelta(refwv, 0), n1 = DimSize(refwv, 0)
		Variable i2 = DimOffset(refwv, 1), d2 = DimDelta(refwv, 1), n2 = DimSize(refwv, 1)
		String u1 = WaveUnits(refwv, 0), u2 = WaveUnits(refwv, 1)
		//
		Variable ix, dx, nx, iy, dy, ny, lx, xw, ly, yw
		Prompt ix, "Map Axis1 : Start"
		Prompt dx, "Map Axis1 : Delta"
		Prompt nx, "Map Axis1 : # of Points"
		Prompt iy, "Map Axis2 : Start"
		Prompt dy, "Map Axis2 : Delta"
		//
		Variable i, j, k
		//		
		if(WaveDims(refwv) == 1) // Slice
			if(mod(maptype, 2) == 1) // 2D SPmap
				if(mapclb == 1)
					DoPrompt "Combine multiple Waves", dx, nx, dy
				else
					DoPrompt "Combine multiple Waves", ix, dx, nx, iy, dy
				endif
				If(V_Flag)
					cd cdfr
					Abort
				Endif
				//
				ny = n/nx
				lx = ix + dx * (nx-1)
				xw = abs(lx-ix)
				ly = iy + dy * (ny-1)
				yw = abs(ly-iy)
				//
				cd $kmwd_prep	
					Make/O/D/N=(n1, nx, ny) $wvstr/Wave=combwv=0
					SetScale/P x, i1, d1, u1, combwv
					if(mapclb==1)
						SetScale/P y, -xw/2, abs(dx), combwv
						SetScale/P z, -yw/2, abs(dy), combwv
					else
						SetScale/P y, ix, dx, combwv
						SetScale/P z, iy, dy, combwv
					endif
				cd $fdstr
				for(i=0; i<nx; i+=1)
					for(j=0; j<ny; j+=1)
						Wave curwv = $StringFromList(k, tarwvlist)
						combwv[][i][j] = curwv[p]
						k += 1
					endfor
				endfor
			else 
				if(mapclb == 1)
					DoPrompt "Combine multiple Waves", dx
				else
					DoPrompt "Combine multiple Waves", ix, dx
				endif
				If(V_Flag)
					cd cdfr
					Abort
				Endif
				//
				nx = n
				lx = ix + dx * (nx-1)
				xw = abs(lx-ix)
				//
				cd $kmwd_prep
					Make/O/D/N=(n1, nx) $wvstr/Wave=combwv
					SetScale/P x, i1, d1, u1, combwv
					if(mapclb==1)
						SetScale/P y, -xw/2, abs(dx), combwv
					else
						SetScale/P y, ix, dx, combwv
					endif
				cd $fdstr
				for(i=0; i<nx; i+=1)
					Wave curwv = $StringFromList(i, tarwvlist)
					combwv[][i] = curwv[p]
				endfor
			endif
		else // ARPES
			if(mod(maptype, 2) == 1) // 2D SPmap
				if(mapclb == 1)
					DoPrompt "Combine multiple Waves", dx, nx, dy
				else
					DoPrompt "Combine multiple Waves", ix, dx, nx, iy, dy
				endif
				If(V_Flag)
					cd cdfr
					Abort
				Endif
				//
				ny = n/nx
				lx = ix + dx * (nx-1)
				xw = abs(lx-ix)
				ly = iy + dy * (ny-1)
				yw = abs(ly-iy)
				//
				cd $kmwd_prep
					Make/O/D/N=(n1, n2, nx, ny) $wvstr/Wave=combwv
					SetScale/P x, i1, d1, u1, combwv
					SetScale/P y, i2, d2, u2, combwv
					if(mapclb == 1)
						SetScale/P z, -xw/2, abs(dx), combwv
						SetScale/P t, -yw/2, abs(dy), combwv
					else
						SetScale/P z, ix, dx, combwv
						SetScale/P t, iy, dy, combwv
					endif
				cd $fdstr
				for(i=0; i<nx; i+=1)
					for(j=0; j<ny; j+=1)
						Wave curwv = $StringFromList(k, tarwvlist)
						combwv[][][i][j] = curwv[p][q]
						k += 1
					endfor
				endfor
			else 
				if(mapclb == 1)
					DoPrompt "Combine multiple Waves", dx
				else
					DoPrompt "Combine multiple Waves", ix, dx
				endif
				If(V_Flag)
					cd cdfr
					Abort
				Endif
				//
				nx = n
				lx = ix + dx * (nx-1)
				xw = abs(lx-ix)
				//
				cd $kmwd_prep
					Make/O/D/N=(n1, n2, nx) $wvstr/Wave=combwv
					SetScale/P x, i1, d1, u1, combwv
					SetScale/P y, i2, d2, u2, combwv
					if(mapclb == 1)
						SetScale/P z, -xw/2, abs(dx), combwv
					else
						SetScale/P z, ix, dx, combwv
					endif
				cd $fdstr
				for(i=0; i<nx; i+=1)
					Wave curwv = $StringFromList(i, tarwvlist)
					combwv[][][i] = curwv[p][q]
				endfor
			endif
		endif		
	//
	cd cdfr
	//
	return combwv
End
	
Function km_call_panel()
	DFREF cdfr = GetDAtaFolderDFR()
	//
	cd $kmwd_prep
	//
	Nvar/Z wvdim, maptype, datatype, slicetype, ismapbidir, da1_r1, da1_r2, da2_r1, da2_r2
	Svar/Z wvpath, fdpath
	Wave/D wswv = Waves_Scaling
	Wave/T wuwv = Waves_Unit
	//
	Variable fs = 10
	NewPanel/W=(350,41,1050,271)/K=1/N=kmp_win as "Data Pre-processing & KM clustering"
	
	GroupBox kmp_grpbox1 pos={12,88},size={485,117},frame=0
	
	// ARPES/Slice data axis 1&2
	Variable voff = (maptype <= 2) ? 20 : 0
	//
	SetDrawLayer UserBack
	SetDrawEnv fsize= fs; DrawText 498,115,"<<<"
	SetDrawEnv fsize= fs; DrawText 600,115,"~"
	if(maptype <= 2)
		SetDrawEnv fsize= fs; DrawText 498,140,"<<<"
		SetDrawEnv fsize= fs; DrawText 600,140,"~"
	endif	
	
	GroupBox kmp_grpbox2 pos={526,75},size={160,55+voff},title=StringFromList((maptype <= 2) ? 0 : 1, "Integration Window;Slice range"),fsize= fs,frame=0
	
	SetVariable kmp_da1_r1 pos={534,100},size={60,19},bodyWidth=60,title=" ",fSize=fs,value=da1_r1, proc=kmp_svarproc
	SetVariable kmp_da1_r2 pos={615,100},size={60,19},bodyWidth=60,title=" ",fSize=fs,value=da1_r2, proc=kmp_svarproc
	
	SetVariable kmp_da2_r1 pos={534,125},size={60,19},bodyWidth=60,title=" ",fSize=fs,value=da2_r1,disable = (maptype <= 2) ? 0 : 3, proc=kmp_svarproc
	SetVariable kmp_da2_r2 pos={615,125},size={60,19},bodyWidth=60,title=" ",fSize=fs,value=da2_r2,disable = (maptype <= 2) ? 0 : 3, proc=kmp_svarproc
	
	PopupMenu kmp_popup1 pos={58,9},size={259,17},bodyWidth=200,title="Map Type : ",fSize=fs,mode=1,popvalue=StringFromList(maptype-1, kmp_maptypelist()),value=#"kmp_maptypelist()",proc=kmp_pop_proc
	PopupMenu kmp_popup2 pos={58,35},size={259,17},bodyWidth=200,title="Data Type : ",fSize=fs,mode=1,popvalue=StringFromList(datatype-1, kmp_datatypelist()),value=#"kmp_datatypelist()",proc=kmp_pop_proc
	if(datatype == 1)
		PopupMenu kmp_popup3 pos={56,62},size={261,17},bodyWidth=200,title="Target Data : ",fSize=fs,mode=1,popvalue=wvpath,value=#"kmp_wvlist()",proc=kmp_pop_proc
	elseif(datatype == 2)
		PopupMenu kmp_popup3 pos={17,62},size={300,17},bodyWidth=200,title="Target Data Folder : ",fSize=fs,mode=1,popvalue=fdpath,value=#"kmp_fdlist()",proc=kmp_pop_proc
	endif
	PopupMenu kmp_popup4 pos={10,210},size={120,17},bodyWidth=120,title="\\JCData Pre-Processing",fSize=fs,mode=0,value=#"\"Load scaling;Update scaling;Map range re-scaling;Enegry calibration;Transpose axis;Flatten data;\"",proc=kmp_popmenu_proc
//
	if(maptype > 2)
		SetDrawEnv fsize= fs; DrawText 336,78,"Slice type : "
		GroupBox kmp_grpbox3 pos={327,61},size={160,20},fSize=11,frame=0
		CheckBox kmp_cbox1 pos={397,64},size={32,15},title="EDC",fSize=fs,value=(slicetype==1) ? 1 : 0, mode=1, proc = kmp_cbox_proc
		CheckBox kmp_cbox2 pos={438,64},size={34,15},title="ADC",fSize=fs,value=(slicetype==2) ? 1 : 0, mode=1, proc = kmp_cbox_proc
	endif
//	Check box for bidirectional mapping
	CheckBox kmp_cbox3 pos={330,10},size={6,14},title="bidirectional", fSize=10, value= ismapbidir, disable = (mod(maptype,2)==1) ? 0 : 2,proc=kmp_cbox_proc
//
	SetVariable kmp_rn pos={27,100},size={81,17},bodyWidth=40,title="Rows : ",fSize=fs,value=wswv[0][0]
	SetVariable kmp_cn pos={9,125},size={99,17},bodyWidth=40,title="Columns : ",fSize=fs,value=wswv[1][0],disable = (wvdim>1) ? 0 : 2
	SetVariable kmp_ln pos={22,150},size={86,17},bodyWidth=40,title="Layers : ",fSize=fs,value=wswv[2][0],disable = (wvdim>2) ? 0 : 2
	SetVariable kmp_chn pos={16,175},size={92,17},bodyWidth=40,title="Chunks : ",fSize=fs,value=wswv[3][0],disable = (wvdim>3) ? 0 : 2
	
	SetVariable kmp_rsta pos={118,100},size={108,17},bodyWidth=70,title="Start : ",fSize=fs,value=wswv[0][1]
	SetVariable kmp_csta pos={118,125},size={108,17},bodyWidth=70,title="Start : ",fSize=fs,value=wswv[1][1],disable = (wvdim>1) ? 0 : 2
	SetVariable kmp_lsta pos={118,150},size={108,17},bodyWidth=70,title="Start : ",fSize=fs,value=wswv[2][1],disable = (wvdim>2) ? 0 : 2
	SetVariable kmp_chsta pos={118,175},size={108,17},bodyWidth=70,title="Start : ",fSize=fs,value=wswv[3][1],disable = (wvdim>3) ? 0 : 2
	
	SetVariable kmp_rdel pos={234,100},size={111,17},bodyWidth=70,title="Delta : ",fSize=fs,value=wswv[0][2]
	SetVariable kmp_cdel pos={234,125},size={111,17},bodyWidth=70,title="Delta : ",fSize=fs,value=wswv[1][2],disable = (wvdim>1) ? 0 : 2
	SetVariable kmp_ldel pos={234,150},size={111,17},bodyWidth=70,title="Delta : ",fSize=fs,value=wswv[2][2],disable = (wvdim>2) ? 0 : 2
	SetVariable kmp_chdel pos={234,175},size={111,17},bodyWidth=70,title="Delta : ",fSize=fs,value=wswv[3][2],disable = (wvdim>3) ? 0 : 2
	
	SetVariable kmp_runi pos={349,100},size={140,19},bodyWidth=100,title="Unit : ",fSize=fs,value=wuwv[0]
	SetVariable kmp_cuni pos={349,125},size={140,19},bodyWidth=100,title="Unit : ",fSize=fs,value=wuwv[1],disable = (wvdim>1) ? 0 : 2
	SetVariable kmp_luni pos={349,150},size={140,19},bodyWidth=100,title="Unit : ",fSize=fs,value=wuwv[2],disable = (wvdim>2) ? 0 : 2
	SetVariable kmp_chuni pos={349,175},size={140,19},bodyWidth=100,title="Unit : ",fSize=fs,value=wuwv[3],disable = (wvdim>3) ? 0 : 2
	
	Button kmp_but1 pos={135,210},size={120,17},title="KM clustering",fSize=fs, proc = kmp_but_proc
	Button kmp_but2 pos={260,210},size={120,17},title="Show clustering results",fSize=fs, proc = kmp_but_proc
	Button kmp_but3 pos={385,210},size={120,17},title="Show Map Viewer",fSize=fs, proc = kmp_but_proc
	//
	cd cdfr
End

Function/S kmp_maptypelist()
	return "4D : ARPES 2D spatial map;3D : ARPES 1D spatial map;3D : Slice 2D spatial map;2D : Slice 1D spatial map;"
End

Function/S kmp_datatypelist()
	return "A volume data;A series of data;"
End

Function/S kmp_fdlist()
	String fdlist = ""
	//
	DFREF cdfr = GetDataFOlderDFR()
	//
	cd root:
	
	fdlist = ReplaceString("\r", ReplaceString("FOLDERS:", ReplaceString(",", ReplaceString(";",DataFolderDir(1), ""), ";root:"), "root:"), "")
	
	cd cdfr
	//
	return fdlist
End

Function/S kmp_wvlist()
	//
	DFREF cdfr = GetDataFolderDFR()
	cd $kmwd_prep
	Nvar/Z maptype
	//
	cd cdfr
	//
	String normalwvlist = "", wvlist = ""
	switch(maptype)
		case 1:
			normalwvlist = WaveList("*", ";", "DIMS:4")
		break
		case 2:
			normalwvlist = WaveList("*", ";", "DIMS:3")
		break
		case 3:
			normalwvlist = WaveList("*", ";", "DIMS:3")
		break
		case 4:
			normalwvlist = WaveList("*", ";", "DIMS:2")
		break
	endswitch
	//
	Variable i, wvnum = ItemsInList(normalwvlist)
	for(i=0; i<wvnum; i+=1)
		Wave curwv = $StringFromList(i, normalwvlist)
		wvlist += GetWavesDataFolder(curwv, 2) + ";"
	endfor
	//
	cd cdfr
	//
	return wvlist
End
 
Function kmp_cbox_proc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	//
	DFREF cdfr = GetDataFolderDFR()
	cd $kmwd_prep
		Nvar/Z slicetype
		strswitch(ctrlName)
			case "kmp_cbox1":
				Variable/G slicetype = 1
				CheckBox kmp_cbox1 value=(slicetype==1) ? 1 : 0
				CheckBox kmp_cbox2 value=(slicetype==2) ? 1 : 0
			break
			case "kmp_cbox2":
				Variable/G slicetype = 2
				CheckBox kmp_cbox1 value=(slicetype==1) ? 1 : 0
				CheckBox kmp_cbox2 value=(slicetype==2) ? 1 : 0
			break
			case "kmp_cbox3":
				Variable/G ismapbidir = checked
			break
		endswitch
	cd cdfr
End


Function kmp_pop_proc(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	//
	DFREF cdfr = GetDataFolderDFR()
	cd $kmwd_prep
	Nvar maptype, datatype, da1_r1, da1_r2, da2_r1, da2_r2, ismapbidir
	//
	strswitch(ctrlName)
		case "kmp_popup1":
			Variable/G maptype = popNum
			ismapbidir = (mod(maptype,2)==1) ? ismapbidir : 0
			CheckBox kmp_cbox3 disable = (mod(maptype,2)==1) ? 0 : 2, value = (mod(maptype,2)==1) ? ismapbidir : 0
		break
		case "kmp_popup2":
			Variable/G datatype = popNum
			if(datatype == 1)
				PopupMenu kmp_popup3, title = "Target Data : ", value = kmp_wvlist()
			elseif(datatype == 2)
				PopupMenu kmp_popup3, title = "Target Data Folder : ", value = kmp_fdlist()
			endif
		break
		case "kmp_popup3":
			if(datatype == 1)
				Wave/SDFR=cdfr tarwv = $popStr
				String/G wvpath = GetWavesDataFolder(tarwv, 2)
				if(maptype > 2)
					Variable st
					Prompt st, "Slice type?", popup "EDC;ADC"
					DoPrompt "Slice Setting", st
					If(V_Flag)
						DoAlert 0, "Re-Select target data"
						cd cdfr
						Abort
					Endif
					Variable/G slicetype = st
				endif
				kmp_ini(tarwv = tarwv)
			elseif(datatype == 2)
				String wvstr = "New_SPmap"
				Variable mapclb
				Prompt wvstr, "Name of creating volume wave"
				Prompt mapclb, "Calibrate mapping scaling w.r.t. Center?", popup "Yes;No"
				DoPrompt "Data Setting Control", wvstr, mapclb
				If(V_Flag)
					Abort
				Endif
				//
				Wave tarwv = kmp_combine_waves(popStr, wvstr, mapclb)
				kmp_ini(tarwv = tarwv)
			endif
			//
			
		break
	endswitch
	//
	cd cdfr
End

Function kmp_popmenu_proc(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	//
	switch(popNum)
		case 1:
			kmp_load_scales()
		break
		case 2:
			kmp_set_scales()
		break
		case 3:
			kmp_map_clb()
		break
		case 4:
			kmp_eng_clb()
		break
		case 5:
			kmp_transpose_Dimension()
		break
		case 6:
			kmp_flatten_data()
		break
	endswitch
End
		
Function kmp_svarproc(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName, varStr, varName
	Variable varNum
	//
	DFREF cdfr = GetDataFolderDFR()
	cd $kmwd_prep
		Nvar maptype, datatype, wvdim, da1_r1, da1_r2, da2_r1, da2_r2, da1_r1pnt, da1_r2pnt, da2_r1pnt, da2_r2pnt
		Svar wvpath
		Wave tarwv = $wvpath
		//
		Variable da1_left, da1_right, da1_del, da1_size, da2_left, da2_right, da2_del, da2_size
		Variable da1_sign, da2_sign, da1_low, da1_high, da2_low, da2_high
		//
		if(maptype <= 2)
			da1_left = DimOffset(tarwv, 0); da1_del = DimDelta(tarwv, 0); da1_size = DimSize(tarwv, 0); da1_right = da1_left + da1_del * (da1_size-1)
			da2_left = DimOffset(tarwv, 1); da2_del = DimDelta(tarwv, 1); da2_size = DimSize(tarwv, 1); da2_right = da2_left + da2_del * (da2_size-1)
			//
			da1_sign = (da1_left < da1_right) ? 1 : -1
			da2_sign = (da2_left < da2_right) ? 1 : -1
			//
			if(da1_sign > 0) // left is smaller
				da1_r1 = (da1_r1 < da1_left) ? da1_left : da1_r1
				da1_r2 = (da1_r2 > da1_right) ? da1_right : da1_r2
				da1_high = max(da1_r1, da1_r2); da1_low = min(da1_r1, da1_r2)
				da1_r1 = da1_low; da1_r2 = da1_high
			else // right is smaller
				da1_r1 = (da1_r1 > da1_left) ? da1_left : da1_r1
				da1_r2 = (da1_r2 < da1_right) ? da1_right : da1_r2
				da1_high = max(da1_r1, da1_r2); da1_low = min(da1_r1, da1_r2)
				da1_r1 = da1_high; da1_r2 = da2_low
			endif
			//	
			if(da2_sign > 0) // left is smaller
				da2_r1 = (da2_r1 < da2_left) ? da2_left : da2_r1
				da2_r2 = (da2_r2 > da2_right) ? da2_right : da2_r2
				da2_high = max(da2_r1, da2_r2); da2_low = min(da2_r1, da2_r2)
				da2_r1 = da2_low; da2_r2 = da2_high
			else // right is smaller
				da2_r1 = (da2_r1 > da2_left) ? da2_left : da2_r1
				da2_r2 = (da2_r2 < da2_right) ? da2_right : da2_r2
				da2_high = max(da2_r1, da2_r2); da2_low = min(da2_r1, da2_r2)
				da2_r1 = da2_high; da2_r2 = da2_low
			endif
			//
			da1_r1pnt = round((da1_r1-da1_left)/da1_del)
			da1_r2pnt = round((da1_r2-da1_left)/da1_del)
			da2_r1pnt = round((da2_r1-da2_left)/da2_del)
			da2_r2pnt = round((da2_r2-da2_left)/da2_del)
		else
			da1_left = DimOffset(tarwv, wvdim-1); da1_del = DimDelta(tarwv, wvdim-1); da1_size = DimSize(tarwv, wvdim-1); da1_right = da1_left + da1_del * (da1_size-1)
			da1_sign = (da1_left < da1_right) ? 1 : -1
			//
			if(da1_sign > 0) // left is smaller
				da1_r1 = (da1_r1 < da1_left) ? da1_left : da1_r1
				da1_r2 = (da1_r2 > da1_right) ? da1_right : da1_r2
				da1_high = max(da1_r1, da1_r2); da1_low = min(da1_r1, da1_r2)
				da1_r1 = da1_low; da1_r2 = da1_high
			else // right is smaller
				da1_r1 = (da1_r1 > da1_left) ? da1_left : da1_r1
				da1_r2 = (da1_r2 < da1_right) ? da1_right : da1_r2
				da1_high = max(da1_r1, da1_r2); da1_low = min(da1_r1, da1_r2)
				da1_r1 = da1_high; da1_r2 = da2_low
			endif
			//
			da1_r1pnt = round((da1_r1-da1_left)/da1_del)
			da1_r2pnt = round((da1_r2-da1_left)/da1_del)
		endif
	cd cdfr
End

Function kmp_but_proc(ctrlName) : ButtonControl
	String ctrlName
	//
	strswitch(ctrlName)
		case "kmp_but1":
			kmp_km_clustering()
		break
		case "kmp_but2": 
			Variable v_opt = 2, v_color = 2, v_color_rev
			Prompt v_opt, "Vertical Position Mode", popup "Mode 0;Mode 1;Mode 2;Mode 3"
			Prompt v_color, "Select color", popup CTabList()
			Prompt v_color_rev, "Reverse coloring?", popup "No;Yes"
			DoPrompt "Visualize k-means clustering results", v_opt, v_color, v_color_rev
			If(V_Flag)
				Abort
			Endif
			kmp_visualize_results(v_opt, v_color, v_color_rev)
		break
		case "kmp_but3": 
			kmp_map_simple_viewer()
			kmp_mv_pntdata_viewer()
		break
	endswitch
End

Function kmp_load_scales()
	DFREF cdfr = GetDataFolderDFR()
	cd $kmwd_prep
		Nvar/Z wvdim
		Svar/Z wvpath
		Wave/Z wv = $wvpath
		Wave/D/Z wswv = Waves_Scaling
		Wave/T/Z wuwv = Waves_Unit
	cd cdfr
	//
		If(!Nvar_Exists(wvdim) || !Svar_Exists(wvpath) || !WaveExists(wswv) || !WaveExists(wuwv) || !WaveExists(wv))
			DoAlert 0, "Missing Settings. Re-start from the beginning"
			IF(V_flag)
				cd cdfr
				Abort
			Endif
		Endif
	//
		String wvlist = WaveList("*", ";", "")+";_none_"
		String aswvstr1, aswvstr2, aswvstr3, aswvstr4
		Variable mapclb, engclb
		Prompt mapclb, "Calibrate mapping scaling w.r.t. Center?", popup "Yes;No"
		Prompt engclb, "Calibrate energy axis from Kinetic energy to Binding energy?", popup "Yes;No"
		Prompt aswvstr1, "Select Axis Scaling Wave for [Rows]" popup wvlist
		Prompt aswvstr2, "Select Axis Scaling Wave for [Columns]" popup wvlist
		Prompt aswvstr3, "Select Axis Scaling Wave for [Layers]" popup wvlist
		Prompt aswvstr4, "Select Axis Scaling Wave for [Chunks]" popup wvlist
		//
		switch(wvdim)
			case 2:
				DoPrompt "Load Scales from Waves", mapclb, engclb, aswvstr1, aswvstr2
			break
			case 3:
				DoPrompt "Load Scales from Waves", mapclb, engclb, aswvstr1, aswvstr2, aswvstr3
			break
			case 4:
				DoPrompt "Load Scales from Waves", mapclb, engclb, aswvstr1, aswvstr2, aswvstr3, aswvstr4
			break
		endswitch
		IF(V_flag)
			cd cdfr
			Abort
		Endif
	//
		Variable i
		for(i=0; i<wvdim; i+=1)
			switch(i)
				case 0:
					Wave/Z curaswv = $aswvstr1
				break
				case 1:
					Wave/Z curaswv = $aswvstr2
				break
				case 2:
					Wave/Z curaswv = $aswvstr3
				break
				case 3:
					Wave/Z curaswv = $aswvstr4
				break
			endswitch
			//
			if(WaveExists(curaswv))
				Variable ix, dx, xn, lx, xw
				Variable asdim = WaveDims(curaswv)
				//
				if(asdim == 1)
					ix = curaswv[0]
					dx = curaswv[1]-curaswv[0]
					xn = DimSize(curaswv, 0)
					lx = ix + dx * (xn-1)
				elseif(asdim == 2) // ex. spatial coordinates
					Variable v00 = curaswv[0][0], v10 = curaswv[1][0], v01 = curaswv[0][1]
					if(v00 - v01 < 10^(-10)) // row is mapping axis
						ix = v00
						dx = v10-v00
						xn = DimSize(curaswv, 0)
						xw = abs(curaswv[xn-1][0]-v00)
					elseif(v00 - v10 < 10^(-10)) // column is mapping axis
						ix = v00
						dx = v01-v00
						xn = DimSize(curaswv, 1)
						xw = abs(curaswv[0][xn-1]-v00)
					endif
					//
					if(mapclb==1)
						ix = -xw/2
						dx = abs(dx)
						lx = xw/2
					else
						lx = ix + dx * (xn-1)
					endif
				endif
				//
				wswv[i][0] = xn
				wswv[i][1] = ix
				wswv[i][2] = dx
				wswv[i][3] = lx
				wuwv[i] = NameOfWave(curaswv)
			endif		
		endfor
	//
		if(engclb == 1)
			kmp_eng_clb()
		endif
	cd cdfr
End

Function kmp_map_clb()
	DFREF cdfr = GetDataFolderDFR()
	cd $kmwd_prep
		Nvar/Z maptype
		Svar/Z wvpath
		Wave/Z wv = $wvpath
		Wave/D/Z wswv = Waves_Scaling
		Wave/T/Z wuwv = Waves_Unit
	cd cdfr
	//
	Variable mapaxis1, mapaxis2
	Variable ix, dx, nx, lx, xw, iy, dy, ny, ly, yw
	//
	String dimlist = ""
	switch(maptype)
		case 1:
			dimlist = "Row;Column;Layer;Chunk"
		break
		case 2:
			dimlist = "Row;Column;Layer"
		break
		case 3:
			dimlist = "Row;Column;Layer"
		break
		case 4:
			dimlist = "Row;Column"
		break
	endswitch
	//
	Prompt mapaxis1, "Select Spatial Map Axis1" popup dimlist
	Prompt mapaxis2, "Select Spatial Map Axis2" popup dimlist
	if(mod(maptype, 2) == 1) // maptype == 1, 3 : 2D map
		DoPrompt "Map range rescaling wrt Center",  mapaxis1, mapaxis2
		If(V_flag)
			cd cdfr
			Abort
		Endif
		//
		nx = wswv[mapaxis1-1][0]; ix = wswv[mapaxis1-1][1]; dx = wswv[mapaxis1-1][2]; lx = ix + dx * (nx-1); xw = abs(lx-ix)
		ny = wswv[mapaxis2-1][0]; iy = wswv[mapaxis2-1][1]; dy = wswv[mapaxis2-1][2]; ly = iy + dy * (ny-1); yw = abs(ly-iy)
		//		
		wswv[mapaxis1-1][1] = -xw/2
		wswv[mapaxis1-1][2] = abs(dx)
		wswv[mapaxis1-1][3] = xw/2
		wswv[mapaxis2-1][1] = -yw/2
		wswv[mapaxis2-1][2] = abs(dy)
		wswv[mapaxis2-1][3] = yw/2
		//
		Execute "SetScale/P "+StringFromList(mapaxis1-1, "x;y;z;t")+", "+num2str(-xw/2)+", "+num2str(abs(dx))+", \""+wuwv[mapaxis1-1]+"\", "+GetWavesDataFolder(wv,2)
		Execute "SetScale/P "+StringFromList(mapaxis2-1, "x;y;z;t")+", "+num2str(-yw/2)+", "+num2str(abs(dy))+", \""+wuwv[mapaxis2-1]+"\", "+GetWavesDataFolder(wv,2)
	else
		DoPrompt "Map range rescaling wrt Center", mapaxis1
		If(V_flag)
			cd cdfr
			Abort
		Endif
		//
		nx = DimSize(wv, mapaxis1-1)
		dx = DimDelta(wv, mapaxis1-1)
		xw = abs(dx*nx)
		ix = -xw/2
		lx = xw/2
		//
		wswv[mapaxis1-1][0] = nx
		wswv[mapaxis1-1][1] = ix
		wswv[mapaxis1-1][2] = dx
		wswv[mapaxis1-1][3] = lx
		//
		Execute "SetScale/P "+StringFromList(mapaxis1-1, "x;y;z;t")+", "+num2str(-xw/2)+", "+num2str(abs(dx))+", \""+wuwv[mapaxis1-1]+"\", "+GetWavesDataFolder(wv,2)
	endif	
End

Function kmp_eng_clb()
	DFREF cdfr = GetDataFolderDFR()
	cd $kmwd_prep
		Svar/Z wvpath
		Wave/Z wv = $wvpath
		Wave/D/Z wswv = Waves_Scaling
		Wave/T/Z wuwv = Waves_Unit
	//
	Variable engaxis, ef
	Prompt engaxis, "Select Energy Axis" popup "Row;Column;Layer;Chunk"
	Prompt ef, "Fermi energy?"
	DoPrompt "Energy rescaling wrt EF", engaxis, ef
	If(V_Flag)
		cd cdfr
		Abort
	Endif
	//
	Variable ie = wswv[engaxis-1][1], de = wswv[engaxis-1][2]
	wswv[engaxis-1][1] = -(ie-ef) 
	wswv[engaxis-1][2] = -de
	//
	Execute "SetScale/P "+StringFromList(engaxis-1, "x;y;z;t")+", "+num2str(wswv[engaxis-1][1])+", "+num2str(wswv[engaxis-1][2])+", \""+wuwv[engaxis-1]+"\", "+GetWavesDataFolder(wv,2)
	//
	switch(engaxis)
		case 1:
			Variable da1_sta = DimOffset(wv, 0), da1_del = DimDelta(wv, 0), da1_size = DimSize(wv, 0)
			Variable/G da1_r1 = da1_sta, da1_r2 = da1_sta + da1_del * (da1_size-1)
			Variable/G da1_r1pnt = 0, da1_r2pnt = da1_size-1	
		break
		case 2:
			Variable da2_sta = DimOffset(wv, 1), da2_del = DimDelta(wv, 1), da2_size = DimSize(wv, 1)
			Variable/G da2_r1 = da2_sta, da2_r2 = da2_sta + da2_del * (da2_size-1)
			Variable/G da2_r1pnt = 0, da2_r2pnt = da2_size-1
		break
	endswitch
	
	cd cdfr
End

Function kmp_set_scales()
	DFREF cdfr = GetDataFolderDFR()
	cd $kmwd_prep
	//
	Nvar/Z wvdim
	Svar/Z wvpath
	Wave/Z wv = $wvpath
	Wave/D/Z wswv = Waves_Scaling
	Wave/T/Z wuwv = Waves_Unit
	//
	If(!Nvar_Exists(wvdim) || !Svar_Exists(wvpath) || !WaveExists(wswv) || !WaveExists(wuwv) || !WaveExists(wv))
		DoAlert 0, "Missing Settings. Re-start from selecting target data"
		IF(V_flag == -1)
			cd cdfr
			Abort
		Endif
	Endif
	//
	DoAlert 1, "Proceed Re-scaling?"
	If(V_Flag == 2)
		cd cdfr
		Abort
	Endif
	//	
	SetScale/P x, wswv[0][1], wswv[0][2], wuwv[0], wv
	SetScale/P y, wswv[1][1], wswv[1][2], wuwv[1], wv
	SetScale/P z, wswv[2][1], wswv[2][2], wuwv[2], wv
	SetScale/P t, wswv[3][1], wswv[3][2], wuwv[3], wv
	//
	cd cdfr
End

Function kmp_transpose_Dimension()
	DFREF cdfr = GetDataFolderDFR()
	cd $kmwd_prep
	//
	Nvar/Z wvdim
	Svar/Z wvpath
	Wave/Z wv = $wvpath
	Wave/D/Z wswv = Waves_Scaling
	Wave/T/Z wuwv = Waves_Unit
	//
	If(!Nvar_Exists(wvdim) || !Svar_Exists(wvpath) || !WaveExists(wswv) || !WaveExists(wuwv) || !WaveExists(wv))
		kmp_ini()
		//
		Nvar/Z wvdim
		Svar/Z wvpath
		Wave/Z wv = $wvpath
		Wave/D/Z wswv = Waves_Scaling
		Wave/T/Z wuwv = Waves_Unit
	Endif
	//
	String wvnote = Note(wv)
	DFREF srcdf = GetWavesDataFolderDFR(wv)
	//
	Variable trmode=1
	String upl = kmp_unitpoplist(wv)
	Prompt trmode, "Transpose mode?" popup upl
	//
	switch(wvdim)
		case 1:
			DoAlert 0, "1D wave is not possible to transpose axis"
		break
		case 2:
			DoAlert 1, "Transpose 2D image?"
			If(V_Flag == 2)
				Abort
			Endif
			
			Make/O/FREE/N=(wswv[1][0], wswv[0][0]) tempwv
			SetScale/P x, wswv[1][1], wswv[1][2], wuwv[1], tempwv
			SetScale/P y, wswv[0][1], wswv[0][2], wuwv[0], tempwv
			Note/K tempwv, wvnote
			//
			tempwv[][] = wv[q][p]
			//
			cd srcdf
				Duplicate/O/D tempwv, $NameOfWave(wv)/Wave = nwv
			cd cdfr
			kmp_ini(tarwv = nwv)
		break
		case 3:
			DoPrompt "Transpose 3D Image Dimension", trmode
			If(V_Flag)
				Abort
			Endif
			//
			Wave trwv = kmp_transpose3D(wv, trmode-1)
			kmp_ini(tarwv = trwv)
		break	
		case 4:
			DoPrompt "Transpose 4D Image Dimension", trmode
			If(V_Flag)
				Abort
			Endif
			//
			Wave trwv = kmp_transpose4D(wv, trmode-1)
			kmp_ini(tarwv = trwv)
		break
	endswitch
	//
	cd cdfr
End

Function/S kmp_unitpoplist(wv)
	Wave wv
	//
	Variable dim = WaveDims(wv)
	String au1=kmp_IsUnitEmpty(WaveUnits(wv, 0)), au2=kmp_IsUnitEmpty(WaveUnits(wv, 1))
	String au3=kmp_IsUnitEmpty(WaveUnits(wv, 2)), au4=kmp_IsUnitEmpty(WaveUnits(wv, 3))
	//
	String poplist=""
	//
	switch(dim)
		case 1:
			poplist += au1 + ";"
		break
		case 2:
			poplist += au1 + ";" + au2 + ";"
		break
		case 3:
			// 0 p q r // 1 2 3 // unchanged
			// 1 p r q // 1 3 2
			// 2 r p q // 3 1 2
			// 3 r q p // 3 2 1
			// 4 q r p // 2 3 1
			// 5 q p r // 2 1 3
			poplist += "Mode0[123] = ["+au1+"]["+au2+"]["+au3+"];Mode1[132] = ["+au1+"]["+au3+"]["+au2+"];Mode2[312] = ["+au3+"]["+au1+"]["+au2+"];Mode3[321] = ["+au3+"]["+au2+"]["+au1+"];Mode4[231] = ["+au2+"]["+au3+"]["+au1+"];Mode5[213] = ["+au2+"]["+au1+"]["+au3+"]"
		break
		case 4:
			//  0 p q r t // 1 2 3 4
			//  1 p q t r // 1 2 4 3		
			//  2 p r q t // 1 3 2 4
			//  3 p r t q // 1 3 4 2
			//  4 p t q r // 1 4 2 3
			//  5 p t r q // 1 4 3 2
 			
 			//  6 q p r t // 2 1 3 4 
			//  7 q p t r // 2 1 4 3		
			//  8 q r p t // 2 3 1 4
			//  9 q r t p // 2 3 4 1
			// 10 q t p r // 2 4 1 3
			// 11 q t r p // 2 4 3 1
			
			// 12 r p q t // 3 1 2 4 
			// 13 r p t q // 3 1 4 2		
			// 14 r q p t // 3 2 1 4
			// 15 r q t p // 3 2 4 1
			// 16 r t p q // 3 4 1 2
			// 17 r t q p // 3 4 2 1
			
			// 18 t p q r // 4 1 2 3 
			// 19 t p r q // 4 1 3 2		
			// 20 t q p r // 4 2 1 3
			// 21 t q r p // 4 2 3 1
			// 22 t r p q // 4 3 1 2
			// 23 t r q p // 4 3 2 1

			poplist += "Mode0[1234] = ["+au1+"]["+au2+"]["+au3+"]["+au4+"];Mode1[1243] = ["+au1+"]["+au2+"]["+au4+"]["+au3+"];Mode2[1324] = ["+au1+"]["+au3+"]["+au2+"]["+au4+"];"
			poplist += "Mode3[1342] = ["+au1+"]["+au3+"]["+au4+"]["+au2+"];Mode4[1423] = ["+au1+"]["+au4+"]["+au2+"]["+au3+"];Mode5[1432] = ["+au1+"]["+au4+"]["+au3+"]["+au2+"];"
			
			poplist += "Mode6[2134] = ["+au2+"]["+au1+"]["+au3+"]["+au4+"];Mode7[2143] = ["+au2+"]["+au1+"]["+au4+"]["+au3+"];Mode8[2314] = ["+au2+"]["+au3+"]["+au1+"]["+au4+"];"
			poplist += "Mode9[2341] = ["+au2+"]["+au3+"]["+au4+"]["+au1+"];Mode10[2413] = ["+au2+"]["+au4+"]["+au1+"]["+au3+"];Mode11[2431] = ["+au2+"]["+au4+"]["+au3+"]["+au1+"];"
			
			poplist += "Mode12[3124] = ["+au3+"]["+au1+"]["+au2+"]["+au4+"];Mode13[3142] = ["+au3+"]["+au1+"]["+au4+"]["+au2+"];Mode14[3214] = ["+au3+"]["+au2+"]["+au1+"]["+au4+"];"
			poplist += "Mode15[3241] = ["+au3+"]["+au2+"]["+au4+"]["+au1+"];Mode16[3412] = ["+au3+"]["+au4+"]["+au1+"]["+au2+"];Mode17[3421] = ["+au3+"]["+au4+"]["+au2+"]["+au1+"];"
		
			poplist += "Mode18[4123] = ["+au4+"]["+au1+"]["+au2+"]["+au3+"];Mode19[4132] = ["+au4+"]["+au1+"]["+au3+"]["+au2+"];Mode20[4213] = ["+au4+"]["+au2+"]["+au1+"]["+au3+"];"
			poplist += "Mode21[4231] = ["+au4+"]["+au2+"]["+au3+"]["+au1+"];Mode22[4312] = ["+au4+"]["+au3+"]["+au1+"]["+au2+"];Mode23[4321] = ["+au4+"]["+au3+"]["+au2+"]["+au1+"];"
		
		break
	endswitch
	//
	return poplist
End

Function/S kmp_IsUnitEmpty(us)
	String us // unit string
	//
	if(strlen(us) <= 0)
		return "empty unit"
	else
		return us
	endif
End

Function/Wave kmp_transpose4D(srcwv, mode)
	Wave srcwv
	Variable mode
	//
	String notestr = Note(srcwv)
	//
	DFREF cdfr = GetDataFolderDFR()
	DFREF srcdfr = GetWavesDataFolderDFR(srcwv)
	cd srcdfr
	//
	//  0 p q r t // 1 2 3 4 -> 1248
	//  1 p q t r // 1 2 4 3 -> 1284		
	//  2 p r q t // 1 3 2 4 -> 1428
	//  3 p r t q // 1 3 4 2 -> 1482
	//  4 p t q r // 1 4 2 3 -> 1824
	//  5 p t r q // 1 4 3 2 -> 1842
 	
 	//  6 q p r t // 2 1 3 4 -> 2148
	//  7 q p t r // 2 1 4 3 -> 2184		
	//  8 q r p t // 2 3 1 4 -> 2418
	//  9 q r t p // 2 3 4 1 -> 2481
	// 10 q t p r // 2 4 1 3 -> 2814
	// 11 q t r p // 2 4 3 1 -> 2841
			
	// 12 r p q t // 3 1 2 4 -> 4128 
	// 13 r p t q // 3 1 4 2 -> 4182	
	// 14 r q p t // 3 2 1 4 -> 4218
	// 15 r q t p // 3 2 4 1 -> 4281
	// 16 r t p q // 3 4 1 2 -> 4812
	// 17 r t q p // 3 4 2 1 -> 4821
			
	// 18 t p q r // 4 1 2 3 -> 8124
	// 19 t p r q // 4 1 3 2 -> 8142		
	// 20 t q p r // 4 2 1 3 -> 8214
	// 21 t q r p // 4 2 3 1 -> 8241
	// 22 t r p q // 4 3 1 2 -> 8412
	// 23 t r q p // 4 3 2 1 -> 8421
	
	String indexlist = "1248;1284;1428;1482;1824;1842;2148;2184;2418;2481;2814;2841;4128;4182;4218;4281;4812;4821;8124;8142;8214;8241;8412;8421"
	String curindex = StringFromList(mode, indexlist)
	
	Variable poridim = log(str2num(curindex[0]))/log(2)
	Variable qoridim = log(str2num(curindex[1]))/log(2)
	Variable roridim = log(str2num(curindex[2]))/log(2)
	Variable toridim = log(str2num(curindex[3]))/log(2)
	
	String cmd = "ImageTransform/TM4D="+curindex+" transpose4D "+GetWavesDataFolder(srcwv,2)
	Execute/Q/Z cmd
	Wave tempwv = M_4DTranspose
	//
	SetScale/P x, DimOffset(srcwv, poridim), DimDelta(srcwv, poridim), WaveUnits(srcwv, poridim), tempwv
	SetScale/P y, DimOffset(srcwv, qoridim), DimDelta(srcwv, qoridim), WaveUnits(srcwv, qoridim), tempwv
	SetScale/P z, DimOffset(srcwv, roridim), DimDelta(srcwv, roridim), WaveUnits(srcwv, roridim), tempwv
	SetScale/P t, DimOffset(srcwv, toridim), DimDelta(srcwv, toridim), WaveUnits(srcwv, toridim), tempwv
	Note/K tempwv, notestr
		
	Duplicate/O/D tempwv, $NameOfWave(srcwv)/Wave = trwv
	KillWaves/Z tempwv
	
	cd cdfr
	return trwv
End

Function/Wave kmp_transpose3D(srcwv, mode) // srcwave will be overwrite
	Wave srcwv
	Variable mode
	//
	String notestr = note(srcwv)
	//
	DFREF cdfr = GetDataFolderDFR()
	DFREF srcdfr = GetWavesDataFolderDFR(srcwv)
	cd srcdfr
	//
	// 0 p q r // 0 1 2
	// 1 p r q // 0 2 1
	// 2 r p q // 2 0 1
	// 3 r q p // 2 1 0
	// 4 q r p // 1 2 0
	// 5 q p r // 1 0 2
		
	switch(mode)
		case 0: // p q r
			Duplicate/FREE srcwv, trfwv
			SetScale/P x, DimOffset(srcwv, 0), DimDelta(srcwv, 0), WaveUnits(srcwv, 0), trfwv
			SetScale/P y, DimOffset(srcwv, 1), DimDelta(srcwv, 1), WaveUnits(srcwv, 1), trfwv
			SetScale/P z, DimOffset(srcwv, 2), DimDelta(srcwv, 2), WaveUnits(srcwv, 2), trfwv
		break
		case 1: // p r q
			MatrixOP/FREE trfwv = transposeVol(srcwv, mode)
			SetScale/P x, DimOffset(srcwv, 0), DimDelta(srcwv, 0), WaveUnits(srcwv, 0), trfwv
			SetScale/P y, DimOffset(srcwv, 2), DimDelta(srcwv, 2), WaveUnits(srcwv, 2), trfwv
			SetScale/P z, DimOffset(srcwv, 1), DimDelta(srcwv, 1), WaveUnits(srcwv, 1), trfwv
		break
		case 2: // p r q
			MatrixOP/FREE trfwv = transposeVol(srcwv, mode)
			SetScale/P x, DimOffset(srcwv, 2), DimDelta(srcwv, 2), WaveUnits(srcwv, 2), trfwv
			SetScale/P y, DimOffset(srcwv, 0), DimDelta(srcwv, 0), WaveUnits(srcwv, 0), trfwv
			SetScale/P z, DimOffset(srcwv, 1), DimDelta(srcwv, 1), WaveUnits(srcwv, 1), trfwv
		break
		case 3: // r q p
			MatrixOP/FREE trfwv = transposeVol(srcwv, mode)
			SetScale/P x, DimOffset(srcwv, 2), DimDelta(srcwv, 2), WaveUnits(srcwv, 2), trfwv
			SetScale/P y, DimOffset(srcwv, 1), DimDelta(srcwv, 1), WaveUnits(srcwv, 1), trfwv
			SetScale/P z, DimOffset(srcwv, 0), DimDelta(srcwv, 0), WaveUnits(srcwv, 0), trfwv
		break
		case 4: // q r p
			MatrixOP/FREE trfwv = transposeVol(srcwv, mode)
			SetScale/P x, DimOffset(srcwv, 1), DimDelta(srcwv, 1), WaveUnits(srcwv, 1), trfwv
			SetScale/P y, DimOffset(srcwv, 2), DimDelta(srcwv, 2), WaveUnits(srcwv, 2), trfwv
			SetScale/P z, DimOffset(srcwv, 0), DimDelta(srcwv, 0), WaveUnits(srcwv, 0), trfwv
		break
		case 5: // q p r
			MatrixOP/FREE trfwv = transposeVol(srcwv, mode)
			SetScale/P x, DimOffset(srcwv, 1), DimDelta(srcwv, 1), WaveUnits(srcwv, 1), trfwv
			SetScale/P y, DimOffset(srcwv, 0), DimDelta(srcwv, 0), WaveUnits(srcwv, 0), trfwv
			SetScale/P z, DimOffset(srcwv, 2), DimDelta(srcwv, 2), WaveUnits(srcwv, 2), trfwv
		break
	endswitch
	//
	Note/K trfwv, notestr
	Duplicate/O/D trfwv, $NameOfWave(srcwv)/Wave=trwv
	//
	cd cdfr
	//
	return trwv
End

Function kmp_flatten_data()
	DFREF cdfr = GetDataFolderDFR()
	cd $kmwd_prep
		Nvar/Z datatype, maptype, slicetype, ismapbidir
		Nvar/Z da1_r1pnt, da1_r2pnt, da2_r1pnt, da2_r2pnt
		Svar/Z wvpath
		
		Variable i, j, k
		
			Wave wv = $wvpath
			Variable i1 = DimOffset(wv, 0), d1 = DimDelta(wv, 0), n1 = DimSize(wv, 0)
			Variable i2 = DimOffset(wv, 1), d2 = DimDelta(wv, 1), n2 = DimSize(wv, 1)
			Variable i3 = DimOffset(wv, 2), d3 = DimDelta(wv, 2), n3 = DimSize(wv, 2)
			Variable i4 = DimOffset(wv, 3), d4 = DimDelta(wv, 3), n4 = DimSize(wv, 3)
			//
			switch(maptype)
				case 1: // ARPES x 2Dmap
					Duplicate/O/D/RMD=[da1_r1pnt, da1_r2pnt][da2_r1pnt, da2_r2pnt][][] wv, $NameOfWave(wv)+"_sub"/Wave=tarwv
					//
					Make/FREE/D/N=(n2,n3,n4) engsumwv // energy integration
					Make/FREE/D/N=(n1,n3,n4) angsumwv // angle integration
					SumDimension/D=0/DEST=engsumwv tarwv
					SumDimension/D=1/DEST=angsumwv tarwv
					//
					Make/FREE/D/N=(n3,n4) sumwv
					SumDimension/D=0/DEST=sumwv engsumwv
					//
					Duplicate/O/D sumwv, $NameOfWave(wv)+"_Imap"/Wave=imap
					SetScale/P x, i3, d3, imap
					SetScale/P y, i4, d4, imap
					// Make Flatten data (iEDCs/iADCs)
					Make/O/D/N=(DimSize(tarwv, 0), n3*n4) $NameOfWave(wv)+"_iEDCs"/Wave=iEDCs
					Make/O/D/N=(DimSize(tarwv, 1), n3*n4) $NameOfWave(wv)+"_iADCs"/Wave=iADCs
					SetScale/P x, DimOffset(tarwv,0), DimDelta(tarwv,0), iEDCs
					SetScale/P x, DimOffset(tarwv,1), DimDelta(tarwv,1), iADCs
					k=0
					if(ismapbidir == 0)
						for(i=0; i<n3; i+=1)		// spmap axis1
							for(j=0; j<n4; j+=1)	// spmap axis2
								MatrixOP/FREE twv1 = Layer(angsumwv, j)
								MatrixOP/FREE twv2 = Col(twv1, i)
								iEDCs[][k] = twv2[p]
								//
								MatrixOP/FREE twv1 = Layer(engsumwv, j)
								MatrixOP/FREE twv2 = Col(twv1, i)
								iADCs[][k] = twv2[p]
								k += 1
							endfor
						endfor
					else // bidirectional mapping
						for(i=0; i<n3; i+=1)		// spmap axis1
							for(j=0; j<n4; j+=1)	// spmap axis2
								if(mod(i, 2) == 0)
									MatrixOP/FREE twv1 = Layer(angsumwv, j)
								else
									MatrixOP/FREE twv1 = Layer(angsumwv, n4-1-j)
								endif
								MatrixOP/FREE twv2 = Col(twv1, i)
								iEDCs[][k] = twv2[p]
								//
								if(mod(i, 2) == 0)
									MatrixOP/FREE twv1 = Layer(engsumwv, j)
								else
									MatrixOP/FREE twv1 = Layer(engsumwv, n4-1-j)
								endif
								MatrixOP/FREE twv2 = Col(twv1, i)
								iADCs[][k] = twv2[p]
								k += 1
								//
								imap[i][j] = sum(twv2)
							endfor
						endfor
					endif
				break
				case 2: // ARPES x 1Dmap
					Duplicate/O/D/RMD=[da1_r1pnt, da1_r2pnt][da2_r1pnt, da2_r2pnt][] wv, $NameOfWave(wv)+"_sub"/Wave=tarwv
					//
					Make/O/D/N=(n1,n3) $NameOfWave(wv)+"_iEDCs"/Wave=iEDCs // angle integration
					Make/O/D/N=(n2,n3) $NameOfWave(wv)+"_iADCs"/Wave=iADCs // energy integration
					SumDimension/D=1/DEST=iEDCs tarwv
					SumDimension/D=0/DEST=iADCs tarwv
					SetScale/P x, DimOffset(tarwv,0), DimDelta(tarwv,0), iEDCs
					SetScale/P x, DimOffset(tarwv,1), DimDelta(tarwv,1), iADCs
					//
					Make/O/D/N=(n3) $NameOfWave(wv)+"_Imap"/Wave=imap
					SumDimension/D=0/DEST=imap iEDCs
					SetScale/P x, i3, d3, imap
				break
				case 3: // Slice x 2Dmap
					Duplicate/FREE/RMD=[da1_r1pnt, da1_r2pnt][][] wv, srcwv
					Make/O/D/N=(DimSize(srcwv, 0), n2*n3) $NameOfWave(wv)+StringFromList(slicetype-1, "_iEDCs;_iADCs")/Wave=slices
					SetScale/P x, DimOffset(srcwv,0), DimDelta(srcwv,0), slices
					Make/O/D/N=(n2,n3) $NameOfWave(wv)+"_Imap"/Wave=imap
					SetScale/P x, i2, d2, imap
					SetScale/P y, i3, d3, imap
					//
					k=0
					if(ismapbidir == 0)
						for(i=0; i<n2; i+=1)		// spmap axis1
							for(j=0; j<n3; j+=1)	// spmap axis2
								MatrixOP/O twv1 = Layer(srcwv, j)
								MatrixOP/O twv2 = Col(twv1, i)
								slices[][k] = twv2[p]
								k += 1
							endfor
						endfor
						//
						SumDimension/D=0/DEST=imap srcwv
						SetScale/P x, i2, d2, imap
						SetScale/P y, i3, d3, imap
					else // bidirectional mapping
						for(i=0; i<n2; i+=1)		// spmap axis1
							for(j=0; j<n3; j+=1)	// spmap axis2
								if(mod(i, 2) == 0)
									MatrixOP/O twv1 = Layer(srcwv, j)
								elseif(mod(i, 2) == 1)
									MatrixOP/O twv1 = Layer(srcwv, n3-1-j)
								endif
								MatrixOP/O twv2 = Col(twv1, i)
								slices[][k] = twv2[p]
								k += 1
								//
								imap[i][j] = sum(twv2)
							endfor
						endfor
					endif
				break
				case 4: // Slice x 1Dmap
					Duplicate/O/D/RMD=[da1_r1pnt, da1_r2pnt][] wv, $NameOfWave(wv)+StringFromList(slicetype-1, "_iEDCs;_iADCs")/Wave=slices
					SetScale/P y, 0, 1, slices
					//
					Make/O/D/N=(n2) $NameOfWave(wv)+"_Imap"/Wave=imap
					SumDimension/D=0/DEST=imap slices
					SetScale/P x, i2, d2, imap
				break
			endswitch
	//
	cd cdfr
End

// KM clustering //
Function kmp_km_clustering() // Data is prepared via data-preprocessing panel and assumed iEDCs and iADCs are prepared
	DFREF cdfr = GetDataFolderDFR()
	//
	cd $kmwd_prep
		Svar wvpath
		Nvar/Z maptype, slicetype
		Wave/D srcwv = $wvpath
		Wave/D wswv = Waves_Scaling
		Wave/T wuwv = Waves_Unit
		//
		Variable tartype = 1, kn = 5, km_opt = 1
		Prompt tartype, "Select target : iEDCs/iADCs", popup "iEDCs;iADCs"
		Prompt kn, "Number of maximum cluster"
		Prompt km_opt, "Modify detailed clustering settings?", popup "No;Yes"
		if(maptype <= 2) // ARPES case
			DoPrompt "k-means clustering", tartype, kn, km_opt
		else // Slice case
			DoPrompt "k-means clustering", kn, km_opt
			tartype = slicetype
		endif
		If(V_flag)
			cd cdfr
			Abort
		Endif	
		//
		Variable/G km_tartype = tartype
		String/G km_tarwvname = NameOfWave(srcwv)+StringFromList(tartype-1, "_iEDCs;_iADCs")
		Wave tarwv = $km_tarwvname
		//
		Variable deadmode=2, distmode = 2, inimode = 2, itnum = 1000
		if(km_opt == 2)
			Prompt deadmode, "How handle dead classes?", popup "Remove the dead class;Keep the last value of the mean vector (default);Assign the class a random mean vector"
			Prompt distmode, "Distance mode?", popup "Manhattan distance;Euclidian distance (default)"
			Prompt inimode, "Initialization method?", popup "Random member-assignment to a class;Initialize classes using randomly selected values from the population (default)"
			Prompt itnum, "Number of stop iterations  (-1 : continue iterating until results unchanged)"
			DoPrompt "k-means clustering : Detailed setting", deadmode, distmode, inimode, itnum
			If(V_flag)
				cd cdfr
				Abort
			Endif	
		endif
		//
		inimode = (inimode == 2) ? 3 : inimode
		//
		Variable xindex = (maptype <= 2) ? 2 : 1
		Variable yindex = (maptype <= 2) ? 3 : 2
		//
		Variable ix = wswv[xindex][1], dx = wswv[xindex][2], nx = wswv[xindex][0]
		Variable iy = wswv[yindex][1], dy = wswv[yindex][2], ny = wswv[yindex][0]
		String xuni = wuwv[xindex], yuni = wuwv[yindex]
		
		Prompt ix, "X : Start"
		Prompt dx, "X : Step"
		Prompt nx, "X : # of Pnts"
		Prompt iy, "Y : Start"
		Prompt dy, "Y : Step"
		Prompt ny, "Y : # of Pnts"
		
		if(mod(maptype, 2) == 1) // maptype == 1, 3 : 2D map
			DoPrompt "k-means clustering : Spatial Map Setting", ix, dx, nx, iy, dy, ny
		else
			DoPrompt "k-means clustering : Spatial Map Setting", ix, dx, nx
		endif
		If(V_flag)
			cd cdfr
			Abort
		Endif
	//
	NewDataFolder/O/S $kmwd_res
	//
		if(itnum > 0)
			KMeans/CAN/dead=(deadmode)/DIST=(distmode)/INIT=(inimode)/TER=1/TERN=(itnum)/ncls=(kn)/out=2 tarwv
		else
			KMeans/CAN/dead=(deadmode)/DIST=(distmode)/INIT=(inimode)/TER=2/ncls=(kn)/out=2 tarwv
		endif
		//
		Wave/D km = W_KMMembers
		//
		if(mod(maptype, 2) == 1) // maptype == 1, 3 : 2D map
			Make/O/D/N=(nx,ny) $NameOfWave(tarwv)+"_KMmember"/Wave=mapkm=0
			SetScale/P x, ix, dx, mapkm
			SetScale/P y, iy, dy, mapkm
		else
			Make/O/D/N=(nx) $NameOfWave(tarwv)+"_KMmember"/Wave=mapkm=0
			SetScale/P x, ix, dx, mapkm
		endif
		//
		kmp_map_member(mapkm, km)
		kmp_sort_by_cluster(tarwv, km)
		mapkm += 1 // Igor counts cluster # from 0. Now, count it from 1.
		//
		Variable v_show, v_opt=2, v_color = 2, v_color_rev
		Prompt v_show, "Visualize k-means clustering results?", popup "Yes;No"
		Prompt v_opt, "Vertical Position Mode", popup "Mode 0;Mode 1;Mode 2;Mode 3"
		Prompt v_color, "Select color", popup CTabList()
		Prompt v_color_rev, "Reverse coloring?", popup "No;Yes"
		DoPrompt "k-means clustering : Visualization", v_show, v_opt, v_color, v_color_rev
		If(V_Flag)
			cd cdfr
			Abort
		Endif
		If(v_show == 1)
			kmp_visualize_results(v_opt, v_color, v_color_rev)
		Endif
	cd cdfr
End

Function kmp_map_member(wv, km)
	Wave wv, km
	//
	Variable i, j, k
	Variable ro = DimSize(wv, 0), co = DimSize(wv, 1)
	//
	if(WaveDims(wv)==2)
		for(i=0; i<ro; i+=1)
			for(j=0; j<co; j+=1)
				wv[i][j] = km[k]
				k += 1
			endfor
		endfor
	else
		wv = km
	endif
End

Function kmp_sort_by_cluster(tarwv, clwv)
	Wave tarwv, clwv 
	// tarwv should be iEDCmap or iADCmap
	Variable cln = WaveMax(clwv) + 1 // To count "0"
	//
	Make/O/D/N=(cln) $NameOfWave(tarwv)+"_clns"/Wave=clns=0
	Make/O/D/N=(cln) $NameOfWave(tarwv)+"_clns_meanInt"/Wave=clint=0
	Variable i, j, k, pn = numpnts(clwv) // 
	SetScale/P x, 1, 1, "Cluster index", clint			
	//
	for(i=0; i<pn; i+=1)	
		clns[clwv[i]] += 1
	endfor
	//
	Variable ir = DimOffset(tarwv, 0), dr = DimDelta(tarwv, 0), rn = DimSize(tarwv, 0)
	//
	for(i=0; i<cln; i+=1)
		Variable curcln = clns[i]
		Make/O/D/N=(rn, curcln) $NameOfWave(tarwv)+"_cl"+num2str(i+1)+"_image"/Wave = clsl_image = 0
		Make/O/D/N=(rn) $NameOfWave(tarwv)+"_cl"+num2str(i+1)+"_sum"/Wave = clsl_sum = 0
		Make/O/D/N=(rn) $NameOfWave(tarwv)+"_cl"+num2str(i+1)+"_ave"/Wave = clsl_ave = 0
		SetScale/P x, ir, dr, clsl_sum, clsl_ave
		//
		for(j=0, k=0; j<pn; j+=1)
			if(clwv[j] == i)
				clsl_image[][k] = tarwv[p][j]
				clsl_sum[] += tarwv[p][j]
				k += 1
			endif
		endfor
		//
		clsl_ave[] = clsl_sum[p]/curcln
		clint[i] = sum(clsl_ave)
	endfor
End

Function kmp_visualize_results(v_opt, v_color, v_color_rev)
	Variable v_opt, v_color, v_color_rev
	//
	DFREF cdfr = GetDataFolderDFR()
	//
	cd $kmwd_prep
		Nvar maptype, wvdim, km_tartype
		Svar wvpath, km_tarwvname
		Wave/D srcwv = $wvpath
		Wave/T wuwv = Waves_Unit
	cd $kmwd_res
		Wave clns = $km_tarwvname+"_clns"
		Wave mapkm = $km_tarwvname+"_KMmember"
		
		Variable i, cln = numpnts(clns)
		Variable wT = 300*(v_opt-1)+10*(v_opt-2), ww1 = 481, ww2 = 470, ww3 = 417	// modify depend on your screen by confirming window macro
		Variable whoff = 5
	//	For coloring
		String curcolor = StringFromList(v_color-1, CTabList())
		ColorTab2Wave $curcolor
		Wave cwv = M_colors
		if(v_color_rev==2)
			Reverse/DIM=0 cwv
		endif
	//
		String wname1 = UniqueName("km_reswin_a", 6, 1)
		String wname2 = UniqueName("km_reswin_b", 6, 1)
		String wname3 = UniqueName("km_reswin_c", 6, 1)
		String wname4 = UniqueName("km_reswin_d", 6, 1)
		
	// Display cluster spatial distribution : 2D
		Display/W=(whoff, wT, 0, 0)/N=$wname1 as "Cluster Distribution"
	//

	cd $kmwd_res
		if(mod(maptype, 2) == 1) // maptype == 1, 3 : 2D map
			AppendImage mapkm
			ModifyImage $NameOfWave(mapkm) ctab= {*,*,$curcolor,v_color_rev-1}
			ModifyGraph margin(right)=79,width=340.157,height=226.772
			ModifyGraph tick=2, mirror=1, tickUnit=1
			ColorScale/C/N=text0/F=0/B=1/A=MC/X=63.24/Y=-0.88 image= $NameOfWave(mapkm)
			AppendText "Cluster index"
			Label left wuwv[wvdim-1]
			Label bottom wuwv[wvdim-2]
		else
			AppendToGraph mapkm
			ModifyGraph mode=3,marker=19,msize=4, tick=2, mirror=1, tickUnit=1
			ModifyGraph zColor($NameOfWave(mapkm))={mapkm,*,*,$curcolor,v_color_rev-1}
			Label left "Cluster index"
			Label bottom wuwv[wvdim-1]
		endif	
	//	
		DoUpdate
		DFREF tempdf = NewFreeDataFolder()
		cd tempdf
		//
			GetWindow $wname1, wsize
			Variable wR1 = V_right
		//
		cd $kmwd_res
	//  Display iEDC/iADC for each cluster averaged by number of members
		String tarslice = StringFromList(km_tartype-1, "iEDCs;iADCs")
		Display/W=(wR1+10, wT, 0, 0)/N=$wname2 as tarslice+" averaged within each cluster"
		String legstr = ""
		Variable colpnt
		for(i=0; i<cln; i+=1)
			colpnt = i * (DimSize(cwv, 0)-1)/(cln-1) 
			String curtrace = km_tarwvname+"_cl"+num2str(i+1)+"_ave"
			AppendToGraph $curtrace
			ModifyGraph margin(right)=73,width=340.157,height=226.772, tick=2, mirror=1, tickUnit=1
			ModifyGraph rgb($curtrace)=(cwv[colpnt][0],cwv[colpnt][1],cwv[colpnt][2])
			if(i != 0)
				legstr += "\r"
			endif
			legstr += "\\s("+PossiblyQuoteName(curtrace)+") cl"+num2str(i+1)+"_ave"
		endfor
		Legend/C/N=FIG_Legend/J/X=-21.5/Y=-1.0 legstr
		//
		Label left "Intensity (mean)"
		if(maptype <= 2) // ARPES
			Label bottom wuwv[km_tartype-1]
		else // Slice
			Label bottom wuwv[0]
		endif
	//	
		DoUpdate
		DFREF tempdf = NewFreeDataFolder()
		cd tempdf
		//
			GetWindow $wname2, wsize
			Variable wR2 = V_right
		cd $kmwd_res
			
	//  Display iEDC/iADC for each cluster integrated over belonging members
		Display/W=(wR2+10, wT, 0, 0)/N=$wname3 as tarslice+" integrated within each cluster"
		legstr = ""
		for(i=0; i<cln; i+=1)
			colpnt = i * (DimSize(cwv, 0)-1)/(cln-1) 
			curtrace =  km_tarwvname+"_cl"+num2str(i+1)+"_sum"
			AppendToGraph $curtrace
			ModifyGraph margin(right)=73,width=340.157,height=226.772, tick=2, mirror=1, tickUnit=1
			ModifyGraph rgb($curtrace)=(cwv[colpnt][0],cwv[colpnt][1],cwv[colpnt][2])
			if(i != 0)
				legstr += "\r"
			endif
			legstr += "\\s("+PossiblyQuoteName(curtrace)+") cl"+num2str(i+1)+"_sum"
		endfor
		Legend/C/N=FIG_Legend/J/X=-21.5/Y=-1.3 legstr
		//		
		Label left "Intensity (sum)"
		if(maptype <= 2) // ARPES
			Label bottom wuwv[km_tartype-1]
		else // Slice
			Label bottom wuwv[0]
		endif
	//	
		DoUpdate
		DFREF tempdf = NewFreeDataFolder()
		cd tempdf
		//
			GetWindow $wname3, wsize
			Variable wR3 = V_right
		cd $kmwd_res
		
	// Display Mean intensity for each cluster
		Wave mi = $km_tarwvname+"_clns_meanInt"
		Duplicate/O mi, $km_tarwvname+"_clns_meanInt_cl_index"/Wave = micl; micl = 1 + p
		Display /W=(wR3+10, wT, 0, 0)/N=$wname4 mi as "Total intensity of each cluster (averaged by # of member)"
		ModifyGraph width=340.157,height=226.772, tick=2, mirror=1, tickUnit=1
		ModifyGraph mode=3,marker=19,msize=4, tick=2, mirror=1, tickUnit=1
		ModifyGraph zColor($NameOfWave(mi))={micl,*,*,$curcolor,v_color_rev-1}
		//
		legstr = "# of member"
		Label left "Total Cluster's Intensity (mean)"
		for(i=0; i<cln; i+=1)
			legstr += "\rcluster"+num2str(i+1)+" = "+num2str(clns[i])
		endfor
		TextBox/C/N=text0/B=1/A=MC/X=38.53/Y=29.96 legstr
		Label bottom "Cluster index"
	//
	cd cdfr
End

/////////////////////////////////////////////////////////////////////////////
//                  Visualization of spatial mapping data                  //
/////////////////////////////////////////////////////////////////////////////

Function kmp_map_simple_viewer()
	DFREF cdfr = GetDataFolderDFR()
	//
	cd $kmwd_prep
		Nvar/Z maptype, slicetype
		Svar/Z wvpath, km_tarwvname
		Wave/D wv = $wvpath, imap = $NameOfWave(wv)+"_Imap"
	cd $kmwd_res
		Wave mapkm = $km_tarwvname+"_KMmember"
	//
		Variable wL = 350, wT = 300
			
		If(WinType("kmp_mv")==0)
			switch(maptype)
				case 1: // ARPES 2D map
					NewDataFolder/O/S $kmwd_view
					Variable/G currow = round(DimSize(imap, 0)/2), curcol = round(DimSize(imap, 1)/2)
					//
					Display/W=(wL,wT,0,0)/N=kmp_mv as "k-means clustering: Spatial Map Viewer"
					AppendImage/B=B1/L=L1 imap
					AppendImage/B=B2/L=L2 mapkm
					ModifyImage $NameOfWave(imap) ctab= {*,*,Terrain,0}
					ModifyImage $NameOfWave(mapkm) ctab= {*,*,Rainbow,0}
					ModifyGraph margin(top)=62,gfSize=11,width=680.315,height=226.772, standoff=0
					ModifyGraph freePos(L1)={0,kwFraction}, freePos(B1)={0,kwFraction}
					ModifyGraph freePos(L2)={0,kwFraction}, freePos(B2)={0,kwFraction}
					ModifyGraph axisEnab(B1)={0,0.49}, axisEnab(B2)={0.51,1}
					Cursor/P/I/C=(65535,65535,65535) A $NameOfWave(imap) currow,curcol
					Cursor/P/I/C=(65535,65535,65535) B $NameOfWave(mapkm) currow,curcol
					ShowInfo
					// Prepare label
					Make/O/T/N=(2) $"cs_ticklabel"/Wave = cstl_txt = {"Min","Max"}
					Make/O/D/N=(2) $"cs_tickpos"/Wave = cstl_pos = {WaveMin(imap),WaveMax(imap)}
					//
					ColorScale/C/N=T1/F=0/B=1/A=MC/X=-10.90/Y=61.50 image=$NameOfWave(imap), vert=0
					ColorScale/C/N=T1 side=2, width=132, tickThick=0, tickLen=0
					ColorScale/C/N=T1 userTicks={cstl_pos,cstl_txt}
					ColorScale/C/N=T1 lblMargin=0
					AppendText "Intensity"
					//
					ColorScale/C/N=T2/F=0/B=1/A=MC/X=40.20/Y=64.00
					ColorScale/C/N=T2 image=$NameOfWave(mapkm), vert=0, side=2, width=132
					AppendText "Cluster index"
				break
				case 2: // ARPES 1D map
					NewDataFolder/O/S $kmwd_view
					Variable/G currow = round(DimSize(imap, 0)/2)
					//
					Display/W=(wL,wT,0,0)/N=kmp_mv as "k-means clustering: Spatial Map Viewer"
					AppendToGraph/B=B1/L=L1 imap
					AppendToGraph/B=B2/L=L2 mapkm
					ModifyGraph margin(top)=85,gfSize=11,width=680.315,height=226.772, standoff=0
					ModifyGraph freePos(L1)={0,kwFraction}, freePos(B1)={0,kwFraction}
					ModifyGraph freePos(L2)={0.55,kwFraction}, freePos(B2)={0,kwFraction}
					ModifyGraph axisEnab(B1)={0,0.45}, axisEnab(B2)={0.55,1}
					ModifyGraph mode=3,marker=19, msize($NameOfWave(imap))=2,msize($NameOfWave(mapkm))=3
					ModifyGraph zColor($NameOfWave(imap))={mapkm,*,*,Rainbow,0}
					ModifyGraph zColor($NameOfWave(mapkm))={mapkm,*,*,Rainbow,0}
					ModifyGraph lblPosMode(L1)=3,lblPos(L1)=60
					ModifyGraph lblPosMode(L2)=3,lblPos(L2)=40
					Label L1 "Intensity"
					Label L2 "Cluster index"
					Cursor/P/H=2/C=(26214,26214,26214) A $NameOfWave(imap) currow
					Cursor/P/H=2/C=(26214,26214,26214) B $NameOfWave(mapkm) currow
					ShowInfo
					//
					TextBox/C/N=T1/B=1/A=MC/X=-44.5/Y=64 "\\Z12Intensity Map"
					TextBox/C/N=T2/B=1/A=MC/X=10.5/Y=64 "\\Z12Cluster Map"
					//
					Make/O/T/N=(2) $"cs_ticklabel"/Wave = cstl_txt = {"Min","Max"}
					Make/O/D/N=(2) $"cs_tickpos"/Wave = cstl_pos = {WaveMin(imap),WaveMax(imap)}
					//
					ColorScale/C/N=T3/F=0/B=1/A=MC/X=-14.5/Y=72.0
					ColorScale/C/N=T3 trace=$NameOfWave(mapkm), vert=0, side=2, width=132
					AppendText "Cluster index"
					//
					ColorScale/C/N=T4/F=0/B=1/A=MC/X=40.2/Y=72.0
					ColorScale/C/N=T4 trace=$NameOfWave(mapkm), vert=0, side=2, width=132
					AppendText "Cluster index"
				break
				case 3: // Slice 2D map
					NewDataFolder/O/S $kmwd_view
					Variable/G currow = round(DimSize(imap, 0)/2), curcol = round(DimSize(imap, 1)/2)
					kmp_mv_slice()
					Wave/D slice_ext = $NameOfWave(wv)+StringFromList(slicetype-1, "_EDC_ext;_ADC_ext")
					//
					Display/W=(wL,wT,0,0)/N=kmp_mv as "k-means clustering: Spatial Map Viewer"
					AppendImage/B=B1/L=L1 imap
					AppendImage/B=B2/L=L2 mapkm
					AppendToGraph/B=B3/L=L3 slice_ext
					ModifyImage $NameOfWave(imap) ctab= {*,*,Terrain,0}
					ModifyImage $NameOfWave(mapkm) ctab= {*,*,Rainbow,0}
					ModifyGraph margin(top)=62,gfSize=11,width=1020.47,height=226.772, standoff=0
					ModifyGraph freePos(L1)={0,kwFraction}, freePos(B1)={0,kwFraction}
					ModifyGraph freePos(L2)={0.35,kwFraction}, freePos(B2)={0,kwFraction}
					ModifyGraph freePos(L3)={0.70,kwFraction}, freePos(B3)={0,kwFraction}
					ModifyGraph axisEnab(B1)={0,0.3}, axisEnab(B2)={0.35,0.65}, axisEnab(B3)={0.7,1.0}
					ModifyGraph mode($NameOfWave(slice_ext))=4,msize($NameOfWave(slice_ext))=2,marker=19
					Cursor/P/I/C=(65535,65535,65535) A $NameOfWave(imap) currow,curcol
					Cursor/P/I/C=(65535,65535,65535) B $NameOfWave(mapkm) currow,curcol
					ShowInfo
					//
					TextBox/C/N=T1/B=1/A=MC/X=-46/Y=56.5 "\\Z12Intensity Map"
					TextBox/C/N=T2/B=1/A=MC/X=-11.5/Y=56.5 "\\Z12Cluster Map"
					TextBox/C/N=T3/B=1/A=MC/X=23/Y=56.5 "\\Z12Point Slice"
					//
					Make/O/T/N=(2) $"cs_ticklabel"/Wave = cstl_txt = {"Min","Max"}
					Make/O/D/N=(2) $"cs_tickpos"/Wave = cstl_pos = {WaveMin(imap),WaveMax(imap)}
					//
					ColorScale/C/N=T4/F=0/B=1/A=MC/X=-26.5/Y=61.50 image=$NameOfWave(imap), vert=0
					ColorScale/C/N=T4 side=2, width=132, tickThick=0, tickLen=0
					ColorScale/C/N=T4 userTicks={cstl_pos,cstl_txt}
					ColorScale/C/N=T4 lblMargin=0
					AppendText "Intensity"
					//
					ColorScale/C/N=T5/F=0/B=1/A=MC/X=8.5/Y=64.00
					ColorScale/C/N=T5 image=$NameOfWave(mapkm), vert=0, side=2, width=132
					AppendText "Cluster index"					
				break
				case 4: // Slice 1D map
					NewDataFolder/O/S $kmwd_view
					Variable/G currow = round(DimSize(imap, 0)/2)
					kmp_mv_slice()
					Wave/D slice_ext = $NameOfWave(wv)+StringFromList(slicetype-1, "_EDC_ext;_ADC_ext")
					//
					Display/W=(wL,wT,0,0)/N=kmp_mv as "k-means clustering: Spatial Map Viewer"
					AppendToGraph/B=B1/L=L1 imap
					AppendToGraph/B=B2/L=L2 mapkm
					AppendToGraph/B=B3/L=L3 slice_ext
					ModifyGraph margin(top)=85,gfSize=11,width=1020.47,height=226.772, standoff=0
					ModifyGraph freePos(L1)={0,kwFraction}, freePos(B1)={0,kwFraction}
					ModifyGraph freePos(L2)={0.35,kwFraction}, freePos(B2)={0,kwFraction}
					ModifyGraph freePos(L3)={0.70,kwFraction}, freePos(B3)={0,kwFraction}
					ModifyGraph axisEnab(B1)={0,0.3}, axisEnab(B2)={0.35,0.65}, axisEnab(B3)={0.7,1.0}
					ModifyGraph mode=3,msize=3,marker=19
					ModifyGraph mode($NameOfWave(slice_ext))=4,msize($NameOfWave(slice_ext))=2
					ModifyGraph zColor($NameOfWave(imap))={mapkm,*,*,Rainbow,0}
					ModifyGraph zColor($NameOfWave(mapkm))={mapkm,*,*,Rainbow,0}
					ModifyGraph lblPosMode(L1)=3,lblPos(L1)=60
					ModifyGraph lblPosMode(L2)=3,lblPos(L2)=40
					Label L1 "Intensity"
					Label L2 "Cluster index"
					Cursor/P/H=2/C=(26214,26214,26214) A $NameOfWave(imap) currow
					Cursor/P/H=2/C=(26214,26214,26214) B $NameOfWave(mapkm) currow
					ShowInfo
					//
					TextBox/C/N=T1/B=1/A=MC/X=-46/Y=64 "\\Z12Intensity Map"
					TextBox/C/N=T2/B=1/A=MC/X=-11.5/Y=64 "\\Z12Cluster Map"
					TextBox/C/N=T3/B=1/A=MC/X=23/Y=64 "\\Z12Point Slice"
					//
					NewDataFolder/O/S $kmwd_view
					Make/O/T/N=(2) $"cs_ticklabel"/Wave = cstl_txt = {"Min","Max"}
					Make/O/D/N=(2) $"cs_tickpos"/Wave = cstl_pos = {WaveMin(imap),WaveMax(imap)}
					//
					ColorScale/C/N=T4/F=0/B=1/A=MC/X=8.5/Y=72.00
					ColorScale/C/N=T4 trace=$NameOfWave(mapkm), vert=0, side=2, width=132
					AppendText "Cluster index"
				break
			endswitch
			//
			SetWindow kmp_mv, hook(kmp_mv_winhook) = kmp_mv_winhook
		else
			DoWindow/F kmp_mv
		endif
		//
		kmp_mv_slice()
		kmp_update_csr_pos()
	cd cdfr
End

Function kmp_update_csr_pos() // 2D map only 
	DFREF cdfr = GetDataFolderDFR()
	cd $kmwd_prep
		Nvar maptype
		Svar wvpath, km_tarwvname
		Wave/D wv = $wvpath, imap = $NameOfWave(wv)+"_Imap"
	cd $kmwd_res
		Wave mapkm = $km_tarwvname+"_KMmember"
	cd $kmwd_view
		Nvar/Z currow, curcol		
		//
		Variable ir, dr, ic, dc, cx, cy
		if(maptype == 1) // ARPES 2D map
			ir = DimOffset(imap, 0); dr = DimDelta(imap, 0)
			ic = DimOffset(imap, 1); dc = DimDelta(imap, 1)
			cx = ir + dr * currow; cy = ic + dc * curcol
			//
			SetDrawLayer/K UserFront
			SetDrawEnv xcoord= prel, ycoord= L1
			SetDrawEnv dash= 11, linefgc= (65535,65535,65535)
			DrawLine 0, cy, 0.49, cy
			//
			SetDrawEnv xcoord= B1, ycoord= prel
			SetDrawEnv dash= 11, linefgc= (65535,65535,65535)
			DrawLine cx, 0, cx, 1
			//
			SetDrawEnv xcoord= prel, ycoord= L2
			SetDrawEnv dash= 11, linefgc= (65535,65535,65535)
			DrawLine 0.51, cy, 1.0, cy
			//
			SetDrawEnv xcoord= B2, ycoord= prel
			SetDrawEnv dash= 11, linefgc= (65535,65535,65535)
			DrawLine cx, 0, cx, 1
		elseif(maptype == 3) // Slice 2D map
			ir = DimOffset(imap, 0); dr = DimDelta(imap, 0)
			ic = DimOffset(imap, 1); dc = DimDelta(imap, 1)
			cx = ir + dr * currow; cy = ic + dc * curcol
			//
			SetDrawLayer/K UserFront
			SetDrawEnv xcoord= prel, ycoord= L1
			SetDrawEnv dash= 11, linefgc= (65535,65535,65535)
			DrawLine 0, cy, 0.3, cy
			//
			SetDrawEnv xcoord= B1, ycoord= prel
			SetDrawEnv dash= 11, linefgc= (65535,65535,65535)
			DrawLine cx, 0, cx, 1
			//
			SetDrawEnv xcoord= prel, ycoord= L2
			SetDrawEnv dash= 11, linefgc= (65535,65535,65535)
			DrawLine 0.35, cy, 0.65, cy
			//
			SetDrawEnv xcoord= B2, ycoord= prel
			SetDrawEnv dash= 11, linefgc= (65535,65535,65535)
			DrawLine cx, 0, cx, 1
		endif
		//
	cd cdfr
End

	
Function kmp_mv_winhook(sw)
	struct WMWinHookStruct & sw
	//
	DFREF cdfr = GetDataFolderDFR() 
	//
	if(StringMatch(WinName(0,1), "kmp_mv"))
		cd $kmwd_prep
			Nvar maptype
			Svar wvpath, km_tarwvname
			Wave/D srcwv = $wvpath, imap = $NameOfWave(srcwv)+"_Imap"
		cd $kmwd_res
			Wave mapkm = $km_tarwvname+"_KMmember"
		cd $kmwd_view
			Nvar/Z currow, curcol, prerow, precol, csr_sw
		// Cursormoed events are called twice for one set of movements of cursors A & B
		// global variable csr_sw is prepared to handle the two events differently.
			if(!Nvar_Exists(csr_sw))
				Variable/G csr_sw = 0
			endif
		//
		If(sw.eventcode == 7) // Cursormoved //
			if(StringMatch(CsrInfo(A, "kmp_mv"), "") || StringMatch(CsrInfo(B, "kmp_mv"), ""))
			// Prevent moving Cursors to outside of image/wave
				if(mod(maptype, 2) == 1) // 2D map
					Cursor/P/I/C=(65535,65535,65535) A $NameOfWave(imap) prerow, precol
					Cursor/P/I/C=(65535,65535,65535) B $NameOfWave(mapkm) prerow, precol
				else // 1D map
					Cursor/P/H=2/C=(26214,26214,26214) A $NameOfWave(imap) prerow
					Cursor/P/H=2/C=(26214,26214,26214) B $NameOfWave(mapkm) prerow
				endif
			else
				if(csr_sw == 0)
					strswitch(sw.cursorName)
						case "A":
							if(mod(maptype, 2) == 1) // 2D map
								// Store current cursor position
								//print "1", pcsr(A), pcsr(B), qcsr(A), qcsr(B)
								Variable/G currow = pcsr(A), curcol = qcsr(A)
								Variable/G prerow = pcsr(A), precol = qcsr(A)
								Cursor/P/I/C=(65535,65535,65535) B $NameOfWave(mapkm) currow, curcol
							else // 1D map
								// Store cursor position
								Variable/G currow = pcsr(A), prerow = pcsr(A)
								Cursor/P/H=2/C=(26214,26214,26214) B $NameOfWave(mapkm) currow
							endif
						break
						case "B":
							if(mod(maptype, 2) == 1) // 2D map
								// Store cursor position
								Variable/G currow = pcsr(B), curcol = qcsr(B)
								Variable/G prerow = pcsr(B), precol = qcsr(B)
								Cursor/P/I/C=(65535,65535,65535) A $NameOfWave(imap) currow, curcol
							else // 1D map
								// Store cursor position
								Variable/G currow = pcsr(B), prerow = pcsr(B)
								Cursor/P/H=2/C=(26214,26214,26214) A $NameOfWave(imap) currow
							endif				
						break
					endswitch
					//
					csr_sw = 1
				else
					strswitch(sw.cursorName)
						case "A": // Cursor B was main move
							if(mod(maptype, 2) == 1) // 2D map
								if(pcsr(A) != pcsr(B) || qcsr(A) != qcsr(B) )
									Cursor/P/I/C=(65535,65535,65535) A $NameOfWave(imap) currow, curcol
								endif
							else // 1D map
								if(pcsr(A) != pcsr(B))
									Cursor/P/H=2/C=(26214,26214,26214) A $NameOfWave(imap) currow
								endif
							endif
						break
						case "B": // Cursor A was main move
							if(mod(maptype, 2) == 1) // 2D map
								if(pcsr(B) != pcsr(A) || qcsr(B) != qcsr(A) )
									Cursor/P/I/C=(65535,65535,65535) B $NameOfWave(mapkm) currow, curcol
								endif
							else // 1D map
								if(pcsr(B) != pcsr(A))
									Cursor/P/H=2/C=(26214,26214,26214) B $NameOfWave(mapkm) currow
								endif
							endif
						break
					endswitch
					csr_sw = 0		
				endif
				// React against the cursor movement
				kmp_mv_slice()
				kmp_update_csr_pos()
			endif
		endif
	endif
	//
	cd cdfr
End
				
Function kmp_mv_slice()
	DFREF cdfr = GetDataFolderDFR()
	
	cd $kmwd_prep
		Nvar/Z maptype, datatype, slicetype
		Svar/Z wvpath, fdstr
		Wave/D srcwv = $wvpath, wswv = Waves_Scaling
	cd $kmwd_view
		Nvar/Z currow, curcol
	// Slice image
	switch(maptype)
		case 1: // src = 4D
			MatrixOP/FREE temp3D = Chunk(srcwv, curcol)
			MatrixOP/FREE temp2D = Layer(temp3D, currow)
			MatrixOP/FREE slice1 = sumRows(temp2D)	
			MatrixOP/FREE slice2 = sumCols(temp2D)^t
			//
			Duplicate/O temp2D, $NameOfWave(srcwv)+"_Image_ext"/Wave=Im_ext
			Duplicate/O slice1, $NameOfWave(srcwv)+"_iEDC_ext"/Wave=iEDC_ext
			Duplicate/O slice2, $NameOfWave(srcwv)+"_iADC_ext"/Wave=iADC_ext
			SetScale/P x, wswv[0][1], wswv[0][2], Im_ext
			SetScale/P y, wswv[1][1], wswv[1][2], Im_ext
			SetScale/P x, wswv[0][1], wswv[0][2], iEDC_ext
			SetScale/P x, wswv[1][1], wswv[1][2], iADC_ext
		break
		case 2: // src = 3D
			MatrixOP/FREE temp2D = Layer(srcwv, currow)
			MatrixOP/FREE slice1 = sumRows(temp2D)	
			MatrixOP/FREE slice2 = sumCols(temp2D)^t
			//
			Duplicate/O temp2D, $NameOfWave(srcwv)+"_Image_ext"/Wave=Im_ext
			Duplicate/O slice1, $NameOfWave(srcwv)+"_iEDC_ext"/Wave=iEDC_ext
			Duplicate/O slice2, $NameOfWave(srcwv)+"_iADC_ext"/Wave=iADC_ext
			SetScale/P x, wswv[0][1], wswv[0][2], Im_ext
			SetScale/P y, wswv[1][1], wswv[1][2], Im_ext
			SetScale/P x, wswv[0][1], wswv[0][2], iEDC_ext
			SetScale/P x, wswv[1][1], wswv[1][2], iADC_ext
		break
		case 3: // src = 3D
			MatrixOP/FREE temp2D = Layer(srcwv, curcol)
			MatrixOP/FREE slice = Col(temp2D, currow)
			Duplicate/O slice, $NameOfWave(srcwv)+StringFromList(slicetype-1, "_EDC_ext;_ADC_ext")/Wave=slice_ext
			SetScale/P x, wswv[0][1], wswv[0][2], slice_ext
		break
		case 4: // src = 2D
			MatrixOP/FREE slice = Col(srcwv, currow)
			Duplicate/O slice, $NameOfWave(srcwv)+StringFromList(slicetype-1, "_EDC_ext;_ADC_ext")/Wave=slice_ext
			SetScale/P x, wswv[0][1], wswv[0][2], slice_ext
		break
	endswitch
	//
	cd cdfr
End

Function kmp_mv_pntdata_viewer()
	DFREF cdfr = GetDataFolderDFR()
	//
	If(WinType("kmp_mv_pd")==0)
		cd $kmwd_prep
			Nvar maptype, datatype
			Svar/Z wvpath, fdstr
			Wave/D srcwv = $wvpath
		cd $kmwd_view
			if(maptype <= 2) // ARPES 
				Wave/D Im_ext = $NameOfWave(srcwv)+"_Image_ext"
				Wave/D iEDC_ext = $NameOfWave(srcwv)+"_iEDC_ext"
				Wave/D iADC_ext = $NameOfWave(srcwv)+"_iADC_ext"
			//
				Variable wL = 350, wT = 700
			//
				Display/W=(wL,wT,0,0)/N=kmp_mv_pd as "Spatial Map Viewer : Point Data"
				AppendToGraph/L=iE_int/B=iE_eng iEDC_ext 
				AppendToGraph/VERT/B=iA_int/L=iA_ang iADC_ext
				AppendImage/B=AR_eng/L=AR_ang Im_ext
				ModifyImage $NameOfWave(Im_ext) ctab= {*,*,Terrain,0}
				ModifyGraph width=453.543,height=340.157, tick=1
				ModifyGraph mirror(iE_eng)=1,mirror(iA_ang)=1
				ModifyGraph noLabel(iE_eng)=2,noLabel(iA_ang)=2
				ModifyGraph standoff(AR_eng)=0,standoff(iE_Int)=0,standoff(iE_eng)=0,standoff(iA_int)=0, standoff(iA_ang)=0
				ModifyGraph lblPosMode(AR_ang)=3,lblPosMode(AR_eng)=3,lblPosMode(iE_int)=3,lblPosMode(iA_int)=3
				ModifyGraph lblPos(AR_ang)=55,lblPos(AR_eng)=45,lblPos(iE_int)=55,lblPos(iA_int)=45
				ModifyGraph tickUnit(AR_ang)=1,tickUnit(AR_eng)=1
				ModifyGraph freePos(AR_ang)={0,kwFraction}, freePos(AR_eng)={0,kwFraction}
				ModifyGraph freePos(iE_int)={0,kwFraction}, freePos(iE_eng)={0.75,kwFraction}
				ModifyGraph freePos(iA_int)={0,kwFraction}, freePos(iA_ang)={0.75,kwFraction}
				ModifyGraph axisEnab(AR_ang)={0,0.7}, axisEnab(AR_eng)={0,0.7}
				ModifyGraph axisEnab(iE_int)={0.75,1}, axisEnab(iE_eng)={0,0.7}
				ModifyGraph axisEnab(iA_int)={0.75,1}, axisEnab(iA_ang)={0,0.7}
				Label AR_ang "Angle"
				Label AR_eng "Energy"
				Label iE_int "Intensity"
				Label iA_int "Intensity"
			//
				SetDrawLayer UserBack
				DrawLine 0.7,0,0.7,0.25
				DrawLine 0.75,0.3,1,0.3
			endif
	else
		DoWindow/F kmp_mv_pd
	endif
	//	
	cd cdfr
End