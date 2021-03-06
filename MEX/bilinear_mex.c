#include <math.h>
#include "mex.h"

// Define the modulo in a more coherent forme than the one from math.h
#define MOD(x, y) ((x) - (y) * floor((double)(x) / (double)(y)))

// Bilinear interpolation, main interface
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {

  // Declare variable
  int i, xf, yf, xc, yc, boundary_x = 0, boundary_y = 0;
  double dxf, dyf, dxc, dyc, x, y, nanval;
  mwSize w, h, m, n, nvals;
  double *x_indx, *y_indx, *tmp, *img, *values;
  bool free_memory = false;

  // Check for proper number of input and output arguments
  if (nrhs < 2) {
    mexErrMsgIdAndTxt("CAST:bilinear:invalidInputs",
        "Not enough input arguments (2 is the minimum) !");

  // In that case, we got an image and a matrix of coordinates
  } else if (nrhs == 2) {

    // Get the size of the coordinates
    m = mxGetM(prhs[1]);
    n = mxGetN(prhs[1]);

    // In that case, the coordinates are properly organized by rows
    if (n == 2) {
      x_indx = mxGetPr(prhs[1]);
      y_indx = x_indx + m;

      // Correct the size of the output
      n = 1;

    // Otherwise, we need to transpose the matrix
    } else if (m == 2) {

      // And thus need to allocate memory for the temporary matrix
      if ((x_indx = mxCalloc(n, sizeof(double))) == NULL) {
        mexErrMsgIdAndTxt("CAST:bilinear:invalidInputs", 
          "Memory allocation failed !");
      }
      if ((y_indx = mxCalloc(n, sizeof(double))) == NULL) {
        mexErrMsgIdAndTxt("CAST:bilinear:invalidInputs",
          "Memory allocation failed !");
      }

      // Copy the data to the new matrix
      tmp = mxGetPr(prhs[1]);
      for (i = 0; i < n; i++) {
        x_indx[i] = tmp[i*2];
        y_indx[i] = tmp[i*2 + 1];
      }

      // Correct the size of the output
      m = 1;

      free_memory = true;

    // Otherwise, something is wrong in the inputs
    } else {
      mexErrMsgIdAndTxt("CAST:bilinear:invalidInputs",
        "Indexes should be organized as a Nx2 subpixel coordinates table !");
    }

  // Otherwise, X and Y coordinates are provided separately
  } else if (nrhs == 3) {

    // Maybe we have both indexes together and the boundary conditions aside...
    if (mxGetNumberOfElements(prhs[1]) != mxGetNumberOfElements(prhs[2])) {

      // Get the size of the coordinates
      m = mxGetM(prhs[1]);
      n = mxGetN(prhs[1]);

      // In that case, the coordinates are properly organized by rows
      if (n == 2) {
        x_indx = mxGetPr(prhs[1]);
        y_indx = x_indx + m;

        // Correct the size of the output
        n = 1;

      // Otherwise, we need to transpose the matrix
      } else if (m == 2) {

        // And thus need to allocate memory for the temporary matrix
        if ((x_indx = mxCalloc(n, sizeof(double))) == NULL) {
          mexErrMsgIdAndTxt("CAST:bilinear:invalidInputs", 
            "Memory allocation failed !");
        }
        if ((y_indx = mxCalloc(n, sizeof(double))) == NULL) {
          mexErrMsgIdAndTxt("CAST:bilinear:invalidInputs",
            "Memory allocation failed !");
        }

        // Copy the data to the new matrix
        tmp = mxGetPr(prhs[1]);
        for (i = 0; i < n; i++) {
          x_indx[i] = tmp[i*2];
          y_indx[i] = tmp[i*2 + 1];
        }

        // Correct the size of the output
        m = 1;

        free_memory = true;

      // Otherwise, something is wrong in the inputs
      } else {
        mexErrMsgIdAndTxt("CAST:bilinear:invalidInputs",
          "Both indexes must have the same number of elements");
      }

      // Retrieve the boundary conditions
      tmp = mxGetPr(prhs[2]);
      boundary_x = (int)tmp[0];

      // Maybe they are not symmetric
      if (mxGetNumberOfElements(prhs[2]) > 1) {
        boundary_y = (int)tmp[1];
      } else {
        boundary_y = boundary_x;
      }

    } else {
      x_indx = mxGetPr(prhs[1]);
      y_indx = mxGetPr(prhs[2]);

      m = mxGetM(prhs[1]); 
      n = mxGetN(prhs[1]);
    }

  // Finally, maybe the boundary conditions are also provided
  } else if (nrhs == 4) {
    if (mxGetNumberOfElements(prhs[1]) != mxGetNumberOfElements(prhs[2])) {
      mexErrMsgIdAndTxt("CAST:bilinear:invalidInputs",
        "Both indexes must have the same number of elements");
    }
    x_indx = mxGetPr(prhs[1]);
    y_indx = mxGetPr(prhs[2]);

    m = mxGetM(prhs[1]); 
    n = mxGetN(prhs[1]);

    // Retrieve the boundary conditions
    tmp = mxGetPr(prhs[3]);
    boundary_x = (int)tmp[0];

    // Maybe they are not symmetric
    if (mxGetNumberOfElements(prhs[3]) > 1) {
      boundary_y = (int)tmp[1];
    } else {
      boundary_y = boundary_x;
    }
  }

  // Ensure the types of the two first arrays at least
  if (!(mxIsDouble(prhs[0]) && mxIsDouble(prhs[1]))) {
    mexErrMsgIdAndTxt("CAST:bilinear:invalidInputs",
        "Input arguments must be of type double.");
  }

  // Prepare the output
  plhs[0] = mxCreateDoubleMatrix(m, n, mxREAL);
  values = mxGetPr(plhs[0]);

  // The size of the image
  h = mxGetM(prhs[0]);
  w = mxGetN(prhs[0]);
  img = mxGetPr(prhs[0]);

  // Precompute the value of NaN
  nanval = mxGetNaN();

  // The bilinear interpolation
  for (i=0; i < m*n; i++) {

    // Adjust the indexes
    x = x_indx[i] - 1;
    y = y_indx[i] - 1;

    // Get the lower index
    xf = floor(x);
    yf = floor(y);

    // Its distance to the index
    dxf = x - xf;
    dyf = y - yf;

    // Avoid a singularity when the index are rounds, get the upper indexes
    if (dxf == 0) {
      xc = xf;
      dxc = 1;
    } else {
      xc = xf + 1;
      dxc = xc - x;
    }

    // Same for y
    if (dyf == 0) {
      yc = yf;
      dyc = 1;
    } else {
      yc = yf + 1;
      dyc = yc - y;
    }

    // Handle the different types of boundary conditions
    switch (boundary_x) {
      // Circular
      case 1 :
        xf = MOD(xf, w);
        xc = MOD(xc, w);

        break;

      // Replicate
      case 2 :
        if (xf >= w) {
          xf = w-1;
        } else if (xf < 0) {
          xf = 0;
        }
        if (xc >= w) {
          xc = w-1;
        } else if (xc < 0) {
          xc = 0;
        }
        break;

      // Symmetric
      case 3 :
        xf = MOD(xf, 2*w);
        xc = MOD(xc, 2*w);

        if (xf >= w) {
         xf = 2*w - xf - 1;
        }
        if (xc >= w) {
         xc = 2*w - xc - 1;
        }
        break;

      // NaN outside
      default :
        break;
    }

    // The same for the y index
    switch (boundary_y) {
      // Circular
      case 1 :
        yf = MOD(yf, h);
        yc = MOD(yc, h);

        break;
      // Replicate
      case 2 :
        if (yf >= h) {
          yf = h-1;
        } else if (yf < 0) {
          yf = 0;
        }
        if (yc >= h) {
          yc = h-1;
        } else if (yc < 0) {
          yc = 0;
        }
        break;
      // Symmetric
      case 3 :
        yf = MOD(yf, 2*h);
        yc = MOD(yc, 2*h);

        if (yf >= h) {
         yf = 2*h - yf - 1;
        }
        if (yc >= h) {
         yc = 2*h - yc - 1;
        }
        break;
      // NaN outside
      default :
        break;
    }

    // Check whether all indexes are valid
    if (xf >= w || yf >= h || xc < 0 || yc < 0 || xc >= w || xf < 0 || yc >= h || yf < 0) {
      values[i] = nanval;

    // Compute the bilinear interpolation
    } else {
      values[i] = img[xf*h + yf] * dxc * dyc +
                  img[xc*h + yf] * dxf * dyc +
                  img[xf*h + yc] * dxc * dyf +
                  img[xc*h + yc] * dxf * dyf;
    }
  }

  // Free the allocated memory
  if (free_memory) {
    mxFree(x_indx);
    mxFree(y_indx);
  }

  return;
}
