% CANARY: Water Quality Event Detection Algorithm Test & Evaluation Tool
% Copyright 2007-2009 Sandia Corporation.
% This source code is distributed under the LGPL License.
% Under the terms of Contract DE-AC04-94AL85000 with Sandia Corporation,
% the U.S. Government retains certain rights in this software.
%
% This library is free software; you can redistribute it and/or modify it
% under the terms of the GNU Lesser General Public License as published by
% the Free Software Foundation; either version 2.1 of the License, or (at
% your option) any later version. This library is distributed in the hope
% that it will be useful, but WITHOUT ANY WARRANTY; without even the
% implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
% See the GNU Lesser General Public License for more details.
%
% You should have received a copy of the GNU Lesser General Public License
% along with this library; if not, write to the Free Software Foundation,
% Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
%
% CANARY is a software package that allows developers to test different
% algorithms and settings on both off- and on-line water-quality data sets.
% Data can come from database or text file sources.
%
% This software was written as part of an Inter-Agency Agreement between
% Sandia National Laboratories and the US EPA NHSRC.
% PARSE_CONFIGFILE get settings from a configuration file
%
% Example DATA = parse_configfile 'my_config.xml';
%         DATA = parse_configfile(my_file);
%
% Patch: r3527 - John Knoll, TetraTech, 5/21/2010
%
% See also SignalData, TimeCfg
function CDef = parse_configfile(ObjEDS, varargin)
  [PATHSTR,NAME,EXT] = fileparts(ObjEDS.configFile);
  switch lower(EXT)
    case {'.edsx','.xml'}
      CDef = cws.parse_xml_config(ObjEDS, varargin{:});
    case {'.edsy','.yaml','.yml'}
      CDef = cws.parse_yaml_config(ObjEDS, varargin{:});
    otherwise
      CDef = [];
  end
end
