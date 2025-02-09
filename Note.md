1. The report presents synthesis results for a reduced 8×8 matrix version. These results can be used to estimate the resource requirements for the larger matrix implementation.

2. The .v files contain Verilog design code, structured as follows:
```
accelerator.v
├── In_controller.v
│   ├── Top_Buffer
│   ├── Buffer
│   └── Data_in <-- input_mem
├── Out_controller.v
│   ├── PE_Matric
│   ├── Res_addr <--| 
│   └── Res_data <--| result_mem
└── PE
    ├── left/up(in)
    ├── right/down(out)
    └── res
```

3. in.npy and result.npy store the two input matrices and the output result matrix respectively.

4. InputGen.py is responsible for matrix generation; Trans.ipynb rearranges the generated matrix data into a hardware-friendly format—specifically the parallelogram shape described in the report; check.ipynb contains the code structure for computing the final results.

5. The report contains the final documentation of the project.

All of the core code is store in `source` folder.