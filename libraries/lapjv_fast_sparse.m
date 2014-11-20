function [assignment,cost] = lapjv_fast_sparse(costMat,resolution)
% LAPJV  Jonker-Volgenant Algorithm for Linear Assignment Problem.
%
% [ASSIGNMENT,COST] = LAPJV_FAST(COSTMAT) returns the optimal column indices,
% ASSIGNMENT assigned to each row and the minimum COST based on the assignment
% problem represented by the COSTMAT, where the (i,j)th element represents
% the cost to assign the jth job to the ith worker.
% COST is the total cost of all assignments.
%
% [ASSIGNMENT,COST] = LAPJV_FAST(COSTMAT,resolution) accepts the second
% input argument as the minimum resolution to differentiate costs between
% assignments. The default is eps.
%
% Known problems: The original algorithm was developed for integer costs.
% When it is used for real (floating point) costs, sometime the algorithm
% will take an extremely long time. In this case, using a reasonably large
% resolution as the second argument can significantly increase the
% solution speed.
%
% See also munkres, Hungarian
%
% Modified to work with sparse matrices:
% Simon Blanchoud
% Gonczy & Naef labs, EPFL
% 2014

% version 1.0 by Yi Cao at Cranfield University on 3rd March 2010
% version 1.1 by Yi Cao at Cranfield University on 19th July 2010
% version 1.2 by Yi Cao at Cranfield University on 22nd July 2010
% version 2.0 by Yi Cao at Cranfield University on 28th July 2010
% version 2.1 by Yi Cao at Cranfield University on 13th August 2010
% version 2.2 by Yi Cao at Cranfield University on 17th August 2010
% version emt3 by Eric Trautmann on 15th March 2011
% version emt3a by Mark Tincknell, MIT Lincoln Laboratory, 13 June 2012

% This Matlab version is developed based on the orginal C++ version coded
% by Roy Jonker @ MagicLogic Optimization Inc on 4 September 1996.
% Reference:
% R. Jonker and A. Volgenant, "A shortest augmenting path algorithm for
% dense and spare linear assignment problems", Computing, Vol. 38, pp.
% 325-340, 1987.

%
% Examples
% Example 1: a 5 x 5 example
%{
[rowsol,cost] = lapjv(magic(5));
disp(rowsol); % 3 2 1 5 4
disp(cost);   %15
%}
% Example 2: 1000 x 1000 random data
%{
n=1000;
A=randn(n)./rand(n);
tic
[a,b]=lapjv(A);
toc                 % about 0.5 seconds 
%}
% Example 3: nonsquare test
%{
n=100;
A=1./randn(n);
tic
[a,b]=lapjv(A);
toc % about 0.2 sec
A1=[A zeros(n,1)+max(max(A))];
tic
[a1,b1]=lapjv(A1);
toc % about 0.01 sec. The nonsquare one can be done faster!
%check results
disp(norm(a-a1))
disp(b-b)
%}

  % Prepare working data
  %validMat = costMat<Inf;
  %validMat = isfinite(costMat);
  %validCol = any(validMat);
  %validRow = any(validMat,2);
  % Now in sparse mode !
  [indxi, indxj, vals] = get_sparse_data_mex(costMat);
  validCol = ismember([1:size(costMat,2)], indxj);
  validRow = ismember([1:size(costMat,1)].', indxi);

  nRows = sum(validRow);
  nCols = sum(validCol);
  n = max(nRows,nCols);
  if ~n
      assignment = [];
      cost = [];
      return
  end

  dMat = sparse(nRows,nCols);  %emt, changed from n
  dMat(1:nRows,1:nCols) = costMat(validRow,validCol);

  %% begin modified code
  [rdim,cdim] = size(dMat);
  M=min(dMat(:));
  if rdim>cdim
      dMat = dMat';
      [rdim,cdim] = size(dMat);
      swapf=true;
  else
      swapf=false;
  end
  dim=cdim;
  dMat = [dMat;2*M+sparse(cdim-rdim,cdim)];

  % Log scaling
  %dMat = dMat + (1-M);
  %dMat = log(dMat);
  % Now in sparse mode !
  [indxi, indxj, vals] = get_sparse_data_mex(dMat);
  logM = log(vals + (1-M));
  logM = logM - max(logM) - 1;

  % get rid of NaNs and Infs
  %realVals = isfinite(dMat);
  %maxcost=max(dMat(realVals))*dim+1;
  %if isempty(maxcost)
  %    maxcost = Inf;
  %end
  %dMat(~realVals)=maxcost;
  % Now in sparse mode !
  realVals = isfinite(logM);
  maxcost=max(logM(realVals))*dim+1;
  if isempty(maxcost)
      maxcost = Inf;
  end
  logM(~realVals)=maxcost;

  dMat = sparse(indxi, indxj, logM, dim, dim, length(logM));

  % moved here by pmm to make sure resolution is finite and smaller
  % than the smallest difference
  % Now in sparse mode !
  if nargin<2
      %vals = unique(dMat(realVals));
      vals = unique([0; logM(realVals)]);
      resolution = min(diff(vals))/2;
  end
  % end modified code
  %%
  % free = zeros(dim,1);      % list of unssigned rows
  % colist = 1:dim;         % list of columns to be scaed in various ways
  % d = zeros(1,dim);       % 'cost-distance' in augmenting path calculation.
  % pred = zeros(dim,1);    % row-predecessor of column in augumenting/alternating path.
  v = zeros(1,dim);         % dual variables, column reduction numbers.
  rowsol = zeros(1,dim)-1;  % column assigned to row in solution
  colsol = zeros(dim,1)-1;  % row assigned to column in solution

  % Now in sparse mode !
  nums = numel(dMat);
  mean_dMat = sum(logM)/nums;
  std_dMat = sqrt((sum((logM - mean_dMat).^2) + (nums-length(logM))*(mean_dMat^2))/nums);

  %if std(dMat(:)) < mean(dMat(:))
  if std_dMat < mean_dMat
      numfree=0;
      free = zeros(dim,1);      % list of unssigned rows
      matches = zeros(dim,1);   % counts how many times a row could be assigned.
      % The Initilization Phase
      % column reduction
      for j=dim:-1:1 % reverse order gives better results
          % find minimum cost over rows
          [v(j), imin] = min(dMat(:,j));
          if ~matches(imin)
              % init assignement if minimum row assigned for first time
              rowsol(imin)=j;
              colsol(j)=imin;
          elseif v(j)<v(rowsol(imin))
              j1=rowsol(imin);
              rowsol(imin)=j;
              colsol(j)=imin;
              colsol(j1)=-1;
          else
              colsol(j)=-1; % row already assigned, column not assigned.
          end
          matches(imin)=matches(imin)+1;
      end

      % Reduction transfer from unassigned to assigned rows
      for i=1:dim
          if ~matches(i)      % fill list of unaasigned 'free' rows.
              numfree=numfree+1;
              free(numfree)=i;
          else
              if matches(i) == 1 % transfer reduction from rows that are assigned once.
                  j1 = rowsol(i);
                  x = dMat(i,:)-v;
                  x(j1) = maxcost;
                  v(j1) = v(j1) - min(x);
              end
          end
      end
  else
      numfree=dim-1;
      [v1 r]=min(dMat);
      free=1:dim;
      [~,c]=min(v1);
      imin=r(c);
      j=c;
      rowsol(imin)=j;
      colsol(j)=imin;
      % matches(imin)=1;
      free(imin)=[];
      x = dMat(imin,:)-v;
      x(j) = maxcost;
      v(j) = v(j) - min(x);
  end
  % Augmenting reduction of unassigned rows
  loopcnt = 0;
  while loopcnt < 2
      loopcnt = loopcnt + 1;
      % scan all free rows
      % in some cases, a free row may be replaced with another one to be scaed next
      k = 0;
      prvnumfree = numfree;
      numfree = 0;    % start list of rows still free after augmenting row reduction.
      while k < prvnumfree
          k = k+1;
          i = free(k);
          % find minimum and second minimum reduced cost over columns
          x = dMat(i,:) - v;
          [umin, j1] = min(x);
          x(j1) = maxcost;
          [usubmin, j2] = min(x);
          i0 = colsol(j1);
          if usubmin - umin > resolution 
              % change the reduction of the minmum column to increase the
              % minimum reduced cost in the row to the subminimum.
              v(j1) = v(j1) - (usubmin - umin);
          else % minimum and subminimum equal.
              if i0 > 0 % minimum column j1 is assigned.
                  % swap columns j1 and j2, as j2 may be unassigned.
                  j1 = j2;
                  i0 = colsol(j2);
              end
          end
          % reassign i to j1, possibly de-assigning an i0.
          rowsol(i) = j1;
          colsol(j1) = i;
          if i0 > 0 % ,inimum column j1 assigned easier
              if usubmin - umin > resolution
                  % put in current k, and go back to that k.
                  % continue augmenting path i - j1 with i0.
                  free(k)=i0;
                  k=k-1;
              else
                  % no further augmenting reduction possible
                  % store i0 in list of free rows for next phase.
                  numfree = numfree + 1;
                  free(numfree) = i0;
              end
          end
      end
  end

  % Augmentation Phase
  % augment solution for each free rows
  for f=1:numfree
      freerow = free(f); % start row of augmenting path
      % Dijkstra shortest path algorithm.
      % runs until unassigned column added to shortest path tree.
      d = dMat(freerow,:) - v;
      pred = freerow(1,ones(1,dim));
      collist = 1:dim;
      low = 1; % columns in 1...low-1 are ready, now none.
      up = 1; % columns in low...up-1 are to be scaed for current minimum, now none.
      % columns in up+1...dim are to be considered later to find new minimum,
      % at this stage the list simply contains all columns.
      unassignedfound = false;
      while ~unassignedfound
          if up == low    % no more columns to be scaned for current minimum.
              last = low-1;
              % scan columns for up...dim to find all indices for which new minimum occurs. 
              % store these indices between low+1...up (increasing up).
              minh = d(collist(up));
              up = up + 1;
              for k=up:dim
                  j = collist(k);
                  h = d(j);
                  if h<=minh
                      if h<minh
                          up = low;
                          minh = h;
                      end
                      % new index with same minimum, put on index up, and extend list.
                      collist(k) = collist(up);
                      collist(up) = j;
                      up = up +1;
                  end
              end
              % check if any of the minimum columns happens to be unassigned.
              % if so, we have an augmenting path right away.
              for k=low:up-1
                  if colsol(collist(k)) < 0
                      endofpath = collist(k); 
                      unassignedfound = true;
                      break
                  end
              end
          end
          if ~unassignedfound
              % update 'distances' between freerow and all unscanned columns,
              % via next scanned column.
              j1 = collist(low);
              low=low+1;
              i = colsol(j1); %line 215
              x = dMat(i,:)-v;
              h = x(j1) - minh;
              xh = x-h;
              k=up:dim;
              j=collist(k);
              vf0 = xh<d;
              vf = vf0(j);
              vj = j(vf);
              vk = k(vf);
              pred(vj)=i;
              v2 = xh(vj);
              d(vj)=v2;
              vf = v2 == minh; % new column found at same minimum value
              j2 = vj(vf);
              k2 = vk(vf);
              cf = colsol(j2)<0; 
              if any(cf) % unassigned, shortest augmenting path is complete.
                  i2 = find(cf,1);
                  endofpath = j2(i2);
                  unassignedfound = true;
              else 
                  i2 = numel(cf)+1;
              end
              % add to list to be scaned right away
              for k=1:i2-1
                  collist(k2(k)) = collist(up);
                  collist(up) = j2(k);
                  up = up + 1;
              end
          end
      end
      % update column prices
      j1=collist(1:last+1);
      v(j1) = v(j1) + d(j1) - minh;
      % reset row and column assignments along the alternating path
      while 1
          i=pred(endofpath);
          colsol(endofpath)=i;
          j1=endofpath;
          endofpath=rowsol(i);
          rowsol(i)=j1;
          if (i==freerow)
              break
          end
      end
  end
  rowsol = rowsol(1:rdim);
  u=diag(dMat(:,rowsol))-v(rowsol)';
  u=u(1:rdim);
  v=v(1:cdim);
  cost = sum(u)+sum(v(rowsol));

  %Modified this part to have the output look like Munkres
  if swapf
    assignment = colsol;
  else
    assignment = rowsol;
  end
  if cost>maxcost
      cost=Inf;
  end
end % lapjv_fast_sparse
