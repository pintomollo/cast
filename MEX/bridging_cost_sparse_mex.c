#include "gaussian_spots.h"

#include "gaussian_spots.c"

// The main of the MATLAB interface
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  // Declare variable
  mwSize m1,n1, m2, n2;
  mwSize nzmax, nzstep;
  mwIndex *irs,*jcs,i,j, count;
  double *x1,*y1,*t1,*x2,*y2,*t2,*rs;
  double dist, dist2, thresh, thresh_lim, thresh2, thresh3, signal1, signal2;
  double weight, gaping, inverse;
  bool is_test;

  // Check for proper number of input and output arguments
  if (nrhs != 6) {
    mexErrMsgIdAndTxt( "CAST:bridging_cost_sparse_mex:invalidNumInputs",
        "Six input arguments required.");
  }

  // Check data type of input argument
  if (!(mxIsDouble(prhs[0]) && mxIsDouble(prhs[1]) && mxIsDouble(prhs[2]))){
    mexErrMsgIdAndTxt( "CAST:bridging_cost_sparse_mex:inputNotDouble",
        "Input arguments must be of type double.");
  }

  // Get the size and pointers to input data
  m1  = mxGetM(prhs[0]);
  n1  = mxGetN(prhs[0]);

  // Get the different pointers to the various columns of data
  x1  = mxGetPr(prhs[0]);
  y1  = x1 + m1;
  t1  = x1 + (n1-1)*m1;

  // Same for the other matrix
  m2  = mxGetM(prhs[1]);
  n2  = mxGetN(prhs[1]);

  x2  = mxGetPr(prhs[1]);
  y2  = x2 + m2;
  t2  = x2 + (n2-1)*m2;

  // Get the thresholds
  thresh = 2*mxGetScalar(prhs[2]);
  inverse = __MAX__(1/__SQR__(thresh), 0.001);
  thresh2 = mxGetScalar(prhs[3]);
  thresh_lim = __SQR__(mxGetScalar(prhs[4]));
  thresh3 = mxGetScalar(prhs[5]);

  // A guess on the number of elements needed
  nzmax=(mwSize)ceil((double)m1*(double)m2*0.1);
  nzstep=(mwSize)__MAX__(ceil((double)nzmax*0.25),1);

  // Prepare the output
  plhs[0] = mxCreateSparse(m1,m2,nzmax,false);
  rs  = mxGetPr(plhs[0]);
  irs = mxGetIr(plhs[0]);
  jcs = mxGetJc(plhs[0]);

  // Need to count the number of elements inserted in the sparse matrix
  count = 0;
  for (i = 0; i < m2; i++) {

    // Get the signal
    signal2 = x2[i + (n2-3)*m2];

    // The number of elements up to the current column
    jcs[i] = count;

    // Now parse the other spots
    for (j = 0; j < m1; j++) {
      dist2 = t2[i]-t1[j];

      dist = (__SQR__(x2[i]-x1[j]) + __SQR__(y2[i]-y1[j]));

      // Only if it passes the thresholds
      if (dist <= __MIN__(thresh*dist2, thresh_lim) && dist2 <= thresh2 && dist2 > 0) {

        // Get the other signal
        signal1 = x1[j + (n1-3)*m1];

        // The weight
        weight = __WGT__(signal2 / signal1);

        // Enforce the intensity threshold
        if (weight <= thresh3) {

          // Add a time-favoring component
          gaping = __SQR__(dist2 / thresh2);

          // Here we might need to increase the number of elements in the matrix
          if (count >= nzmax){
            nzmax += nzstep;

            mxSetNzmax(plhs[0], nzmax);
            mxSetPr(plhs[0], mxRealloc(rs, nzmax*sizeof(double)));
            mxSetIr(plhs[0], mxRealloc(irs, nzmax*sizeof(mwIndex)));

            rs  = mxGetPr(plhs[0]);
            irs = mxGetIr(plhs[0]);
          }

          // Store it in the matrix
          rs[count] = -fast_exp(-inverse*(dist + gaping));
          irs[count] = j;

          count++;
        }
      }
    }
  }

  // Requried to finalize the sparse matrix
  jcs[m2] = count;
}
