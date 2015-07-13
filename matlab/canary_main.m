%CANARY_MAIN Runs the main CANARY control structure
%
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
%
%  Usage:
%       canary_main( filename , path , logfile )
%
%  Example:
%       canary_main( 'my_canary_config.xml' , 'C:\My Data' , 'log.txt' );
%
%  Authors
%    David B. Hart, Katherine A. Klise, Shawn Martin, Sean A. McKenna,
%    Marguerite Sorensen, Eric Vugrin, Mark P. Wilson
%
%  See also canary, canarye
%
function ret = canary_main ( filename , filepath , logfile , DeBug)
  % Create a "data" structure
  import cws.*;
  data.SIGNALS = [];
  ret = 0;
  data.INPUTS.handle = [];
  data.OUTPUTS.handle = [];
  data.MESSENGER = [];
  try
    if ~isempty(filepath)
      cd(filepath);
    end
    data = parse_configfile(filename,filepath,logfile);
  catch CErr
    cws.errTrace(CErr);
  end
  %disp(['TEMPDIR VERSION'])
  %disp(['Saving all files to the temporary directory: ',tempdir])
  global DEBUG_LEVEL;
  DEBUG_LEVEL = DeBug;
  global LOG_FILE 
  LOG_FILE = fullfile(filepath,'status.log');
  global LOGLEVEL
  LOGLEVEL = 0;
  cws.logger('enter canary_main',0,'',true);
  try
    CDS = data.SIGNALS;
    CDS.initialize();
    if DeBug > 1,
      fprintf(2,'%s',CDS.toString());
    end
    % start Messaging Service
    MSG = data.MESSENGER;
    try
      MSG.initialize({CDS.locations.name});
      MSG.b_done = false;
      if DeBug > 1,
        fprintf(2,'%s',MSG.toString());
      end;
    catch ERR
      if DeBug, cws.trace(ERR.identifier,ERR.message); end;
    end
    MSG.data_dir_path = filepath;
    % initialize all Connections
    for iCon = 1:length(data.INPUTS)
      try
        INP = data.INPUTS(iCon).handle;
        INP.initialize();
        if DeBug > 1,
          fprintf(2,'%s',INP.toString());
        end;
        INP.data_dir_path = filepath;
      catch ERR
        if DeBug, cws.errTrace(ERR); end;
      end
    end
    
    for iCon = 1:length(data.OUTPUTS)
      OUT = data.OUTPUTS(iCon).handle;
      try
        OUT.initialize();
        if DeBug > 1,
          fprintf(2,'%s',OUT.toString());
        end;
        OUT.data_dir_path = filepath;
      catch ERR
        if DeBug, cws.errTrace(ERR); end;
      end
    end
    
    switch lower(MSG.run_mode)
      case {'real-time','realtime','on-line','online','xml','eddies','real time'}
        fprintf(2,'Switching logging to new file: %s.%s.log\n',logfile,datestr(now,'yyyy-mm-dd'));
        diary off;
        CDS.fn_logfile = logfile;
        fn_logfile = sprintf('%s.%s.log',logfile,datestr(now,'yyyy-mm-dd'));
        diary(fn_logfile)
        diary on
        fprintf(2,'#Logging starting: %s\n',datestr(now,'yyyy-mm-dd HH:MM:SS'));
        HH = canary_gui(data);  %% This is where the GUI is launched
        MSG.GUIHandle = HH;
        set(HH,'Name',['CANARY - ',filename]);
        drawnow;
      otherwise
        HH = canary_gui(data);  %% This is where the GUI is launched
        MSG.GUIHandle = HH;
        set(HH,'Name',['CANARY RUNNING - ',filename]);
        drawnow;
    end
    
    sec2 =  MSG.time.poll_int;
    while (~MSG.b_done) % The main data processing loop
      % get a new message and parse it out
      ret = cws.process_message([],[],MSG,CDS,data);
      if ishandle(HH),
        drawnow;
        pause(sec2);
      else
        pause(sec2);
      end
    end
    if ishandle(HH),
      close(HH);
    end
    [fpath,file,ext] = fileparts(filename);
    save(fullfile(MSG.data_dir_path,[file '.edsd']),'CDS','-MAT');

    if MSG.b_done, ret = -1;
    end
    % Save Files / Do Outputs
    if DeBug > 1, display(CDS.toString()); end;
    
    warning off MATLAB:Java:ConvertFromOpaque;
    warning off MATLAB:structOnObject;
    
    if ~MSG.IsBatch
      try
        if ~isempty(CDS.combined_filenames),
          CDS.saveCurrent(CDS.locations(1).handle.lastIdxEvaluated,MSG.data_dir_path);
          CDS = combineEdsdFiles(CDS.combined_filenames{1},CDS.combined_filenames{end},true);
          save(fullfile(MSG.data_dir_path,[file '.edsd']),'CDS','-MAT','-V7');
        end
      catch ERR
        cws.errTrace(ERR)
      end
    end
    if DeBug,
      save(fullfile(MSG.data_dir_path,[CDS.case_prefix 'debug.mat']),'data');
      MSG.saveMessageList(fullfile(MSG.data_dir_path,[CDS.case_prefix 'debug.xml']));
    end
    
    for iLoc = 1:length(CDS.locations)
      LOC = CDS.locations(iLoc).handle;
      NAM = CDS.locations(iLoc).name;
      maxVidx = max([LOC.sigs CDS.alarm(LOC.sigs) LOC.calib]);
      VALS = struct(CDS);
      VALS.locations = struct('handle',LOC,'name',NAM);
      VALS.values=VALS.values(:,1:maxVidx);
      VALS.nsigs = maxVidx;
      V = cws.Signals(VALS);
      BAK = CDS;
      CDS = V;
      DatFile = fullfile(MSG.data_dir_path,[CDS.case_prefix NAM,'.edsd']);
      save(DatFile,'CDS','-MAT');
      SumFile = fullfile(MSG.data_dir_path,[CDS.case_prefix NAM,'.summary.txt']);
      LOC.createSummaryStats(CDS,SumFile);
      SumFile = fullfile(MSG.data_dir_path,[CDS.case_prefix NAM,'.summary.yml']);
      LOC.createSummaryYAML(CDS,SumFile);
      CDS = BAK;
    end
    
  catch errCMain
    cws.errTrace(errCMain);
    save(fullfile(filepath,'core.mat'));
    % Print out error debugging information
    if (DeBug),
      assignin('base','debugData',data);
    else
      if isa(data.SIGNALS,'handle') && data.SIGNALS.isvalid,
        data.SIGNALS.delete();
      end
      for iCon = 1:length(data.INPUTS) % disconnect any remaining inputs
        if isfield(data.INPUTS(iCon),'handle'),
          INP = data.INPUTS(iCon).handle;
          if isa(INP,'handle') && INP.isvalid;
            INP.delete();
          end
        end
      end
      for iCon = 1:length(data.OUTPUTS) % disconnect any remaining outputs
        if isfield(data.OUTPUTS(iCon),'handle'),
          OUT = data.OUTPUTS(iCon).handle;
          if isa(OUT,'handle') && OUT.isvalid;
            OUT.delete();
          end
        end
      end
      if isa(data.MESSENGER,'handle') && data.MESSENGER.isvalid,
        data.MESSENGER.delete();
      end
    end
    delete(timerfindall);
    rethrow(errCMain);
  end
  
  % Clean Up successful object usages
  if CDS.isvalid,
    CDS.delete(); % get rid of huge SignalData object
  end
  for iCon = 1:length(data.INPUTS) % disconnect any remaining inputs
    INP = data.INPUTS(iCon).handle;
    if INP.isvalid, INP.disconnect(); end;
  end
  for iCon = 1:length(data.OUTPUTS) % disconnect any remaining outputs
    OUT = data.OUTPUTS(iCon).handle;
    if OUT.isvalid, OUT.disconnect(); end;
  end
  if MSG.isvalid,
    MSG.disconnect(); % disconnect the messenger service
  end
  cws.logger('exit  canary_main');
end
