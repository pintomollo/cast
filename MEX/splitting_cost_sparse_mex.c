#include "gaussian_spots.h"

#include "gaussian_spots.c"

// The main of the MATLAB interface
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  // Declare variable
  mwSize m1,n1, m2, n2;
  mwSize nzmax, nzstep;
  mwIndex *irs,*jcs,i,j, count, *irs2, *jcs2;
  const mxArray *spots, *links;
  double *x1,*y1,*t1,*i1,*x2,*y2,*t2,*i2,*rs, *rs2;
  double dist, dist2, thresh, thresh2, thresh3, signal1, signal2, signal_next;
  double weight, alt_weight, alt_move, eps;
  bool is_test;

  // Check for proper number of input and output arguments
  if (nrhs == 4) {
    is_test = true;
  } else if (nrhs == 8) {
    is_test = false;
  } else {
    mexErrMsgIdAndTxt( "CAST:splitting_cost_sparse_mex:invalidNumInputs",
        "Four or eight input arguments required.");
  }

  // Check data type of input argument
  if (!(mxIsDouble(prhs[0]) && mxIsDouble(prhs[1]) && mxIsDouble(prhs[2]))){
    mexErrMsgIdAndTxt( "CAST:splitting_cost_sparse_mex:inputNotDouble",
        "Input arguments must be of type double.");
  }
  if (!is_test && !(mxIsCell(prhs[6]) && mxIsCell(prhs[7]))) {
    mexErrMsgIdAndTxt( "CAST:splitting_cost_sparse_mex:inputNotCell",
        "Input arguments (7, 8) must be of type cell.");
  }

  // Get the size and pointers to input data
  m1  = mxGetM(prhs[0]);
  n1  = mxGetN(prhs[0]);

  // Get the different pointers to the various columns of data
  x1  = mxGetPr(prhs[0]);
  y1  = x1 + m1;
  i1  = x1 + (n1-2)*m1;
  t1  = x1 + (n1-1)*m1;

  // Same for the other matrix
  m2  = mxGetM(prhs[1]);
  n2  = mxGetN(prhs[1]);

  x2  = mxGetPr(prhs[1]);
  y2  = x2 + m2;
  i2  = x2 + (n2-2)*m2;
  t2  = x2 + (n2-1)*m2;

  // Get the two thresholds
  thresh = __SQR__(mxGetScalar(prhs[2]));
  thresh2 = mxGetScalar(prhs[3]);

  // And our zero value
  eps = mxGetEps();

  // A guess on the number of elements needed
  nzmax=(mwSize)ceil((double)m1*(double)m2*0.1);
  nzstep=(mwSize)__MAX__(ceil((double)nzmax*0.25),1);

  // Here we only check if they could interact
  if (is_test) {

    // Returns a boolean list of interactions
    plhs[0] = mxCreateDoubleMatrix(1,m2,mxREAL);
    rs  = mxGetPr(plhs[0]);

    for (i = 0; i < m2; i++) {
      for (j = 0; j < m1; j++) {
        dist2 = t1[j]-t2[i];

        // The distance
        dist = (__SQR__(x2[i]-x1[j]) + __SQR__(y2[i]-y1[j])) / __SQR__(dist2);

        // Check if possible
        if (dist < thresh && dist2 <= thresh2 && dist2 > 0) {
          rs[i] = true;
          break;
        }
      }
    }

  // Here we compute the actual costs
  } else {

    // The last threshold
    thresh3 = mxGetScalar(prhs[4]);

    // The average movement, for the alternative costs
    alt_move = mxGetScalar(prhs[5]);

    // The list of all information, to retrieve the intensitites
    spots = prhs[6];
    links = prhs[7];

    // Prepare the output
    plhs[0] = mxCreateSparse(m1,m2,nzmax,false);
    rs  = mxGetPr(plhs[0]);
    irs = mxGetIr(plhs[0]);
    jcs = mxGetJc(plhs[0]);

    // And the alternative weights
    plhs[1] = mxCreateDoubleMatrix(m2, 1,mxREAL);
    rs2  = mxGetPr(plhs[1]);

    // Need to count the number of elements inserted in the sparse matrix
    count = 0;
    for (i = 0; i < m2; i++) {

      // The number of elements up to the current column
      jcs[i] = count;

      // The current and previous signals
      signal2 = get_signal(t2[i]-1, i2[i]-1, spots);
      signal_next = get_next_signal(t2[i]-1, i2[i]-1, spots, links);

      // The alternative weight
      alt_weight = __WGT__(signal2 / signal_next);
      rs2[i] = __MAX__(alt_move*alt_weight, eps);

      // Now the actual weights
      for (j = 0; j < m1; j++) {
        dist2 = t1[j]-t2[i];

        dist = (__SQR__(x2[i]-x1[j]) + __SQR__(y2[i]-y1[j])) / __SQR__(dist2);

        // But only if it passes the threshold
        if (dist < thresh && dist2 <= thresh2 && dist2 > 0) {

          // Get the other signal
          signal1 = get_signal(t1[j]-1, i1[j]-1, spots);

          // The weight
          weight = __WGT__(signal2 / (signal1 + signal_next));

          // Enforce the intensity threshold
          if (weight <= thresh3) {

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
            rs[count] = __MAX__(dist*weight, eps);
            irs[count] = j;

            count++;
          }
        }
      }
    }

    // Requried to finalize the sparse matrix
    jcs[m2] = count;
  }
}
