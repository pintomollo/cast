function hgroup = plot_paths(h, paths, color)

  if (nargin == 1)
    paths = h;
    h = gca;
    color = 'y';
  elseif (nargin == 2)
    if (ischar(paths))
      color = paths;
      paths = h;
      h = gca;
    end
  end

  if (~iscell(paths))
    paths = {paths};
  end

  npaths = length(paths);
  if (ischar(color))
    color = [color, color(ones(1, npaths-length(color)))];
    color = color(1:npaths);
  else
    color = [color; color(ones(1, npaths-size(color,1)),:)];
    color = color(1:npaths,:);
  end

  if (strncmp(get(h, 'Type'), 'hggroup',7))
    hgroup = h;
  else
    hgroup = hggroup('Parent', h);
  end

  haxes = get(hgroup, 'Parent');

  status = get(haxes, 'NextPlot');
  set(haxes,'NextPlot', 'add');

  hlines = get(hgroup, 'Children');
  nlines = length(hlines);

  count = 0;
  for i=1:npaths

    curr_paths = paths{i};

    if (ischar(color))
      curr_color = color(i);
    else
      curr_color = color(i,:);
    end

    if (size(curr_paths, 1) > 1)
      count = count + 1;

      if (count>nlines)
        line('XData', curr_paths(:,1), 'YData', curr_paths(:,2), 'Parent', hgroup, 'Color', curr_color, 'Marker', '*');
      else
        set(hlines(count), 'XData', curr_paths(:,1), 'YData', curr_paths(:,2), 'Color', curr_color);
      end
    end
  end

  set(haxes,'NextPlot', status);

  delete(hlines(count+1:nlines))

  return;
end
