function [c,vargout] = phreeqCO2(varargin)
% PHREEQCO2 Use PHREEQC to compute equilibrium carbonate system from any
% pair of DIC, ALK, pCO2, or pH
%
%   Ted Present, 2020
%   Requires installation of <a href="matlab:
%   web('https://www.usgs.gov/software/phreeqc-version-3')">IPhreeqcCOM</a>.
% 
%   C = PHREEQCO2('dic',DIC,'alk',ALK) computes the CO2 system for default
%   surface seawater from DIC and ALK and returns a cell array C with
%   headers in the first column and results in the second
%
%   C = PHREEQCO2('ph',PH,'alk',ALK,'S',S) computes the CO2 system for 
%   seawater from pH and ALK, and scales concentrations of other species in
%   default surface seawater by salinity
%
%   C = PHREEQCO2('pH',PH,'alk',ALK,'S',S,'Ca',25) computes the CO2 system 
%   for seawater from pH and ALK, and scales concentrations of undefined
%   species in default surface seawater by salinity (i.e. Ca is left at 25
%   mmol/kg, but Na will be S/35*469 mmol/kg)
%
%   C = PHREEQCO2(...,'database','C:\phreeqc\database\pitzer.dat') changes
%   the default database
%
%   DIC, ALK, HCO3, CO3 units are mmol/kg
%   pCO2 units in ppm
%   Temperature in degrees C
%
%   Default surface seawater:
%     Temperature = 25 degree C, Salinity = 35 ppt
%     Na :   469  mmol/kg         Cl :   546  mmol/kg
%     Mg :   53   mmol/kg         SO4:   28   mmol/kg
%     Ca :   10.3 mmol/kg         Si :   0    mmol/kg
%     K  :   10.2 mmol/kg         PO4:   0    mmol/kg
%
%   For more information, see the <a href="matlab:
%   web('https://www.usgs.gov/software/phreeqc-version-3')">USGS PHREEQC website</a>.
%
%   See also CO2SYS.

%% Defaults
% Default surface seawater composition:
default_T   = 25;    % degrees C
default_S   = 35;    % mg/g
default_Ca  = 10.3;  % mmol/kg
default_Mg  = 53;    % mmol/kg
default_K   = 10.2;  % mmol/kg
default_SO4 = 28;    % mmol/kg
default_Na  = 469;   % mmol/kg
default_Cl  = 546;   % mmol/kg
default_Si  = 0;  % mmol/kg
default_Po4 = 0;     % mmol/kg

% Default database location:
default_db = 'C:\phreeqc\IPhreeqcCOM-3.6.2-15100\database\pitzer.dat';

%% Parse input parameters
p = inputParser;
    addParameter(p,'ph',   NaN, @isnumeric);
    addParameter(p,'dic',  NaN, @isnumeric);
    addParameter(p,'alk',  NaN, @isnumeric);
    addParameter(p,'pco2', NaN, @isnumeric);
    
    addParameter(p,'database',default_db,@isstring);
    
    addParameter(p,'T',default_T,@isnumeric);
    addParameter(p,'S',default_S,@isnumeric);
    addParameter(p,'Ca',default_Ca,@isnumeric);
    addParameter(p,'Mg',default_Mg,@isnumeric);
    addParameter(p,'K',default_K,@isnumeric);
    addParameter(p,'SO4',default_SO4,@isnumeric);
    addParameter(p,'Na',default_Na,@isnumeric);
    addParameter(p,'Cl',default_Cl,@isnumeric);
    addParameter(p,'Si',default_Si,@isnumeric);
    addParameter(p,'PO4',default_Po4,@isnumeric);
parse(p,varargin{:});

T = p.Results.T;
S = p.Results.S;
Ca = p.Results.Ca;
Mg = p.Results.Mg;
K = p.Results.K;
SO4 = p.Results.SO4;
Na = p.Results.Na;
Cl = p.Results.Cl;
Si = p.Results.Si;
PO4 = p.Results.PO4;

%% Adjust salinity
sal_factor = S / default_S;
if sal_factor ~= 1
    if  ~any(strcmpi(varargin,'Ca'))
        Ca = sal_factor.*default_Ca;
    end
    if ~any(strcmpi(varargin,'Mg'))
        Mg = sal_factor.*default_Mg;
    end
    if ~any(strcmpi(varargin,'K'))
        K = sal_factor.*default_K;
    end
    if ~any(strcmpi(varargin,'SO4'))
        SO4 = sal_factor.*default_SO4;
    end
    if ~any(strcmpi(varargin,'Na'))
        Na = sal_factor.*default_Na;
    end
    if ~any(strcmpi(varargin,'Cl'))
        Cl = sal_factor.*default_Cl;
    end
    if ~any(strcmpi(varargin,'Si'))
        Si = sal_factor.*default_Si;
    end
    if ~any(strcmpi(varargin,'PO4'))
        PO4 = sal_factor.*default_Po4;
    end
end

%% Convert numeric compositions to text to feed to COM server
s_temp = num2str(T);
s_Ca = num2str(Ca);
s_Mg = num2str(Mg);
s_K = num2str(K);
s_SO4 = num2str(SO4);
s_Na = num2str(Na);
s_Cl = num2str(Cl);
s_Si = num2str(Si);
s_PO4 = num2str(PO4);

s_DIC = num2str(p.Results.dic);
s_pH = num2str(p.Results.ph);
s_ALK = num2str(p.Results.alk);
s_logPCO2 = num2str(log10(p.Results.pco2./1e6));

%% Script and run PHREEQC
% initialize IPhreeqcCOM server and database
ipc = actxserver('IPhreeqcCOM.Object');
ipc.LoadDatabase(p.Results.database);
ipc.ClearAccumulatedLines;


% % test for Lizzy--- this PHASE block has to be up here, with an END
% % statement, or else the code won't parse correctly if DIC and pCO2 is called,
% % because that also has a PHASES and EQUILIBRIUM_PHASES block.
%     ipc.AccumulateLine( 'PHASES');
%             ipc.AccumulateLine( 'Ikaite');
%                 ipc.AccumulateLine( 'CaCO3:6H2O = Ca+2 + CO3-2 + 6 H2O');
%                 ipc.AccumulateLine( 'log_k -8.406'); % I just put in calcites to test
%                  ipc.AccumulateLine( 'delta_h -2.297 kcal');
%     ipc.AccumulateLine( 'END');
% %

% define solution
ipc.AccumulateLine ('SOLUTION 1 ');
ipc.AccumulateLine ('units mmol/kgw');
ipc.AccumulateLine([   'temp',     sprintf('\t'),      s_temp   ]);
ipc.AccumulateLine([   'Ca',       sprintf('\t'),      s_Ca     ]);
ipc.AccumulateLine([   'Mg',       sprintf('\t'),      s_Mg     ]);
ipc.AccumulateLine([   'K',        sprintf('\t'),      s_K      ]);
ipc.AccumulateLine([   'S(6)',     sprintf('\t'),      s_SO4     ]);
ipc.AccumulateLine([   'Na',       sprintf('\t'),      s_Na     ]);
ipc.AccumulateLine([   'Cl',       sprintf('\t'),      s_Cl     ]);
ipc.AccumulateLine([   'Si',       sprintf('\t'),      s_Si     ]);
ipc.AccumulateLine([   'P',        sprintf('\t'),      s_PO4    ]);

if ~isnan(p.Results.ph)
    ipc.AccumulateLine([   'pH',       sprintf('\t'),      s_pH     ]);
    if ~isnan(p.Results.dic) % input is pH and DIC:
        ipc.AccumulateLine([   'C(4)',     sprintf('\t'),      s_DIC    ]);
    elseif ~isnan(p.Results.alk) % input is pH and ALK:
        ipc.AccumulateLine(['Alkalinity',  sprintf('\t'),      s_ALK    ]);
    elseif ~isnan(p.Results.pco2) % input is pH and pCO2
        % give a guess of '2' for total CO2, but equilibrate CO2(g):
        ipc.AccumulateLine(['C(4)',sprintf('\t'),'2',sprintf('\t'),'CO2(g) ', s_logPCO2  ]);
    end
elseif ~isnan(p.Results.dic)
    ipc.AccumulateLine([   'C(4)',     sprintf('\t'),      s_DIC    ]);
    if ~isnan(p.Results.alk) % input is DIC and ALK:
        ipc.AccumulateLine(['Alkalinity',  sprintf('\t'),      s_ALK    ]);
    elseif ~isnan(p.Results.pco2) % input is DIC and pCO2
        % use a trick modelled off of PHREEQC Example 8:
        % create a fake "Fix_CO2" phase with which we force the solution to come
        % to equilibrium, but let the pH adjust by NaOH addition/removal using all
        % other reactions in the database.  This method leads to small
        % changes in Na+ that might affect speciation if that alkalinity
        % were actually from other cations in the sample
        ipc.AccumulateLine( 'PHASES');
            ipc.AccumulateLine( 'Fix_CO2');
                ipc.AccumulateLine( 'CO2(g) = CO2(g)');
                ipc.AccumulateLine( 'log_k = 0.0');
            ipc.AccumulateLine( 'END');
        ipc.AccumulateLine( 'USE solution 1');
        ipc.AccumulateLine( 'EQUILIBRIUM PHASES');
            ipc.AccumulateLine(['Fix_CO2',sprintf('\t'),s_logPCO2,sprintf('\t'),'NaOH',sprintf('\t'),'10']);
    end
elseif ~isnan(p.Results.alk)
    ipc.AccumulateLine(['Alkalinity',  sprintf('\t'),      s_ALK    ]);
    if ~isnan(p.Results.pco2) % input is ALK and pCO2
        % give a guess of '2' for total CO2, but equilibrate CO2(g):
        ipc.AccumulateLine(['C(4)',sprintf('\t'),'2',sprintf('\t'),'CO2(g) ', s_logPCO2  ]);
    end
end

% define results ouput
ipc.AccumulateLine ('SELECTED_OUTPUT');
ipc.AccumulateLine ('-reset false'); % default to not reporting outputs unless specified
ipc.AccumulateLine ('-high_precision true');
ipc.AccumulateLine ('-activities CO2 HCO3- CO3-2');
ipc.AccumulateLine ('-totals C(4)');
ipc.AccumulateLine ('si aragonite');
ipc.AccumulateLine ('si calcite');
ipc.AccumulateLine ('si dolomite');
ipc.AccumulateLine ('si CO2(g)');
ipc.AccumulateLine ('si gypsum');
ipc.AccumulateLine ('si halite');
% ipc.AccumulateLine ('si ikaite');
ipc.AccumulateLine ('-ph  true');
ipc.AccumulateLine ('-temperature  true');
ipc.AccumulateLine ('-alkalinity  true');

% Run PHREEQC and get results
ipc.RunAccumulated;
output = ipc.GetSelectedOutputArray';

%% Return results
switch nargout
    case {0,1}
        c = output;
    otherwise
        c = output;
        vargout = []; % find a way to order output manually
%         idx = find(strcmp(output,'si_halite'));
%         vargout(idx) = output{idx,2};
end

end