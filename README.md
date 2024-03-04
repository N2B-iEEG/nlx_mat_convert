# nlx_mat_convert
Cross-OS functions for Neuralynx-MATLAB conversion, plus some customized utilities

## Origin of MATLAB MEX files
- (Windows) developed by and owned by Neuralynx Inc. Available on https://neuralynx.fh-co.com/research-software/
- (Linux and Mac OS X) Compiled under gcc by [Prof. Ueli Rutishauser](https://www.urut.ch/new/serendipity/). Available on https://www.urut.ch/new/serendipity/index.php?/pages/nlxtomatlab.html.

MEX files from both sources are included in this repository without modification.

## Extra utilities
- `nlx_hdr_parse`: Parse the text header of a Neuralynx file and return a struct with all header fields.
- `nlx_read_full`: Read a Neuralynx file (`.ncs` or `.nev`) and return all data in a struct.
- `nlx_all_nev`: Read all NEV files in a directory and organize all found events into a table.
- `nlx_seg`: Write segments of the data into new directories. Useful for organizing data by different runs.
- `nlx_merge`: If there are multiple files for events or recordings (resulting from allowing `Create new files per recording` in Neuralynx acquisition setup), merge them into one file.