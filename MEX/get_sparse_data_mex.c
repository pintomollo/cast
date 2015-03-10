#include <string.h> 
#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  // Declare variable
  mwSize m, n;
  mwIndex *irs,*jcs,i,count,curr_col;
  double *indx1,*indx2,*value, *rs;

  // Check for proper number of input and output arguments
  if (nrhs != 1) {
    mexErrMsgIdAndTxt( "CAST:get_sparse_data_mex:invalidNumInputs",
        "One input argument required.");
  }

  // Check data type of input argument
  if (!(mxIsSparse(prhs[0]) && mxIsDouble(prhs[0]))) {
    mexErrMsgIdAndTxt( "CAST:get_sparse_data_mex:inputNotSparse",
        "Input arguments must be of type double sparse.");
  }

  // Get the size and pointers to input data
  m  = mxGetM(prhs[0]);
  n  = mxGetN(prhs[0]);

  // Get the sparse data
  rs  = mxGetPr(prhs[0]);
  irs = mxGetIr(prhs[0]);
  jcs = mxGetJc(prhs[0]);

  // The total number of data
  count = jcs[n];

  // Prepare the output
  plhs[0] = mxCreateDoubleMatrix(count, 1, mxREAL);
  plhs[1] = mxCreateDoubleMatrix(count, 1, mxREAL);
  plhs[2] = mxCreateDoubleMatrix(count, 1, mxREAL);

  // Get the pointers
  indx1  = mxGetPr(plhs[0]);
  indx2  = mxGetPr(plhs[1]);
  value  = mxGetPr(plhs[2]);

  // Copy the values to the corresponding array
  memcpy(value, rs, count*sizeof(double));

  // Now loop over the indexes to reconstruct their (i,j) coordinates
  curr_col = 0;
  for (i = 0; i < count; i++) {
    while (jcs[curr_col] <= i) {
      curr_col++;
    }
    indx1[i] = irs[i] + 1;
    indx2[i] = curr_col;
  }
}
