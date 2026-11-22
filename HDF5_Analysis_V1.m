classdef HDF5_Analysis_V1 < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        HDF5AnalysisAppUIFigure  matlab.ui.Figure
        Table2SumaryofSpectraldataLabel  matlab.ui.control.Label
        Table1TofDataLabel       matlab.ui.control.Label
        NeighbourmzEditField     matlab.ui.control.NumericEditField
        NeighbourmQLabel         matlab.ui.control.Label
        ExportSumDataButton      matlab.ui.control.Button
        ExportTofDataButton      matlab.ui.control.Button
        UITable2                 matlab.ui.control.Table
        mzEditField              matlab.ui.control.NumericEditField
        mzEditFieldLabel         matlab.ui.control.Label
        UITable1                 matlab.ui.control.Table
        GetfileButton            matlab.ui.control.Button
        FilenameEditField        matlab.ui.control.EditField
        FilenameEditFieldLabel   matlab.ui.control.Label
        UIAxes2                  matlab.ui.control.UIAxes
        UIAxes                   matlab.ui.control.UIAxes
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: GetfileButton
        function GetfileButtonPushed(app, event)
            %% Clear previous data
            app.UITable1.Data = {};
            app.UITable2.Data = {};
            cla(app.UIAxes);
            cla(app.UIAxes2);

            %% Select file
            [file, path] = uigetfile('*.h5','Select HDF5 file');
            if isequal(file,0)
                return;
            end

            fullFile = fullfile(path,file);
            app.FilenameEditField.Value = file;

            try
                %% Inputs
                targetMQ    = app.mzEditField.Value;
                neighbourMQ = app.NeighbourmzEditField.Value;

                %% Read MassAxis
                massAxis = double(h5read(fullFile,'/FullSpectra/MassAxis'));
                massAxis = massAxis(:);

                lowerMQ = targetMQ - neighbourMQ;
                upperMQ = targetMQ + neighbourMQ;

                lbIdxUsed = find(massAxis >= lowerMQ,1,'first');
                ubIdxUsed = find(massAxis <= upperMQ,1,'last');

                if isempty(lbIdxUsed) || isempty(ubIdxUsed) || lbIdxUsed > ubIdxUsed
                    error('No valid index found for selected m/z range.');
                end

                idxRange   = lbIdxUsed:ubIdxUsed;
                massValues = massAxis(idxRange);
                nIdx       = numel(idxRange);

                %% Read TofData
                infoTof = h5info(fullFile,'/FullSpectra/TofData');
                szTof   = double(infoTof.Dataspace.Size);

                massDimTof = find(szTof == numel(massAxis),1,'first');
                if isempty(massDimTof)
                    error('No TofData dimension matches MassAxis length.');
                end

                startTof = ones(1,numel(szTof));
                countTof = szTof;

                startTof(massDimTof) = lbIdxUsed;
                countTof(massDimTof) = nIdx;

                tofData = h5read(fullFile,'/FullSpectra/TofData',startTof,countTof);
                tofData = double(tofData);

                permOrder = [setdiff(1:ndims(tofData),massDimTof,'stable'), massDimTof];
                tofData   = permute(tofData,permOrder);
                tofData   = reshape(tofData,[],nIdx);

                %% Summaries
                RowSummary     = sum(tofData,2,'omitnan');
                ColumnSummary  = sum(tofData,1,'omitnan');
                ColumnAverage  = mean(tofData,1,'omitnan');

                ColumnSummary_Total  = sum(ColumnSummary,'omitnan');
                ColumnAverage_Total  = mean(ColumnAverage,'omitnan');

                finalNumericData = [tofData, RowSummary; ...
                    ColumnSummary, ColumnSummary_Total; ...
                    ColumnAverage, ColumnAverage_Total];

                rowLabels = [string((1:size(tofData,1))'); ...
                    "ColumnSummary"; ...
                    "ColumnAverage"];

                tableData = cell(size(finalNumericData,1), size(finalNumericData,2)+1);

                tableData(:,1) = cellstr(rowLabels);
                tableData(:,2:end) = num2cell(finalNumericData);

                app.UITable1.Data = tableData;

                %% Two-line column headers
                headerNames = cell(1,nIdx+2);
                headerNames{1} = 'Time (s)';

                for k = 1:nIdx
                    headerNames{k+1} = sprintf('idx %d\n%.5f', ...
                        idxRange(k), ...
                        massValues(k));
                end

                headerNames{end} = 'Row\nSummary';

                app.UITable1.ColumnName = headerNames;

                %% Plot 1: Scan vs RowSummary
                scanNumber = (1:size(tofData,1))';

                plot(app.UIAxes, scanNumber, RowSummary, '-o', ...
                    'LineWidth',1.2,'MarkerSize',4);

                xlabel(app.UIAxes,'Time (s)');
                ylabel(app.UIAxes,'Integrated Ion Intensity by Time (cps)');
                title(app.UIAxes,'Time-wise ion intensity');

                grid(app.UIAxes,'on');

                %% Plot 2: MassAxis vs ColumnSummary
                plot(app.UIAxes2, massValues, ColumnSummary, '-o', ...
                    'LineWidth',1.2,'MarkerSize',4);

                xlabel(app.UIAxes2,'m/z');
                ylabel(app.UIAxes2,'Integrated Ion Intensity by m/z (cps)');
                title(app.UIAxes2,'Mass bin intensity summary');

                grid(app.UIAxes2,'on');

                %% Read SumSpectrum

                infoSum = h5info(fullFile,'/FullSpectra/SumSpectrum');
                szSum   = double(infoSum.Dataspace.Size);

                massDimSum = find(szSum == numel(massAxis),1,'first');

                startSum = ones(1,numel(szSum));
                countSum = szSum;

                startSum(massDimSum) = lbIdxUsed;
                countSum(massDimSum) = nIdx;

                sumData = h5read(fullFile,'/FullSpectra/SumSpectrum',startSum,countSum);
                sumData = double(sumData);

                permOrderSum = [setdiff(1:ndims(sumData),massDimSum,'stable'), massDimSum];
                sumData      = permute(sumData,permOrderSum);
                sumData      = reshape(sumData,[],nIdx);

                SumSpectrum_RowSummary = sum(sumData,2,'omitnan');

                app.UITable2.Data = num2cell([sumData, SumSpectrum_RowSummary]);

                headerNames2 = cell(1,nIdx+1);

                for k = 1:nIdx
                    headerNames2{k} = sprintf('idx %d\n%.5f', ...
                        idxRange(k), ...
                        massValues(k));
                end

                headerNames2{end} = 'Row\nSummary';

                app.UITable2.ColumnName = headerNames2;

            catch ME
                uialert(app.HDF5AnalysisAppUIFigure,ME.message,'HDF5 Error');
            end
        end

        % Button pushed function: ExportTofDataButton
        function ExportTofDataButtonPushed(app, event)
            % Open file save dialog
            [file, path] = uiputfile( ...
                {'*.xlsx', 'Excel Files (*.xlsx)'; ...
                '*.csv',  'CSV Files (*.csv)'; ...
                '*.txt',  'Text Files (*.txt)'}, ...
                'Save UITable1 As');

            if isequal(file, 0)
                return;
            end

            filePath = fullfile(path, file);

            % Get UITable1 data
            tableData   = app.UITable1.Data;
            columnNames = app.UITable1.ColumnName;

            if isempty(tableData)
                uialert(app.HDF5AnalysisAppUIFigure, 'UITable1 is empty.', 'Export Error');
                return;
            end

            % Convert column names to cell array of char
            if isstring(columnNames)
                columnNames = cellstr(columnNames);
            elseif ischar(columnNames)
                columnNames = {columnNames};
            end

            % Make valid MATLAB variable names for table export
            validNames = matlab.lang.makeValidName(columnNames, 'ReplacementStyle', 'delete');
            validNames = matlab.lang.makeUniqueStrings(validNames);

            try
                % Convert cell array to table column by column
                nCols = size(tableData, 2);
                T = table();

                for c = 1:nCols
                    colData = tableData(:, c);

                    % If entire column is numeric, convert to numeric array
                    if all(cellfun(@(x) isnumeric(x) && isscalar(x), colData))
                        T.(validNames{c}) = cell2mat(colData);
                    else
                        % Otherwise keep as string column
                        T.(validNames{c}) = string(colData);
                    end
                end

                % Save file
                [~,~,ext] = fileparts(filePath);

                switch lower(ext)
                    case '.xlsx'
                        writetable(T, filePath, 'WriteVariableNames', true);

                    case '.csv'
                        writetable(T, filePath, 'WriteVariableNames', true);

                    case '.txt'
                        writetable(T, filePath, 'Delimiter', '\t', 'WriteVariableNames', true);

                    otherwise
                        error('Unsupported file format.');
                end

            catch ME
                uialert(app.HDF5AnalysisAppUIFigure, ME.message, 'Export Error');
            end
        end

        % Button pushed function: ExportSumDataButton
        function ExportSumDataButtonPushed(app, event)
            % Open file save dialog
            [file, path] = uiputfile( ...
                {'*.xlsx', 'Excel Files (*.xlsx)'; ...
                '*.csv',  'CSV Files (*.csv)'; ...
                '*.txt',  'Text Files (*.txt)'}, ...
                'Save UITable1 As');

            if isequal(file, 0)
                return;
            end

            filePath = fullfile(path, file);

            % Get UITable1 data
            tableData   = app.UITable2.Data;
            columnNames = app.UITable2.ColumnName;

            if isempty(tableData)
                uialert(app.HDF5AnalysisAppUIFigure, 'UITable1 is empty.', 'Export Error');
                return;
            end

            % Convert column names to cell array of char
            if isstring(columnNames)
                columnNames = cellstr(columnNames);
            elseif ischar(columnNames)
                columnNames = {columnNames};
            end

            % Make valid MATLAB variable names for table export
            validNames = matlab.lang.makeValidName(columnNames, 'ReplacementStyle', 'delete');
            validNames = matlab.lang.makeUniqueStrings(validNames);

            try
                % Convert cell array to table column by column
                nCols = size(tableData, 2);
                T = table();

                for c = 1:nCols
                    colData = tableData(:, c);

                    % If entire column is numeric, convert to numeric array
                    if all(cellfun(@(x) isnumeric(x) && isscalar(x), colData))
                        T.(validNames{c}) = cell2mat(colData);
                    else
                        % Otherwise keep as string column
                        T.(validNames{c}) = string(colData);
                    end
                end

                % Save file
                [~,~,ext] = fileparts(filePath);

                switch lower(ext)
                    case '.xlsx'
                        writetable(T, filePath, 'WriteVariableNames', true);

                    case '.csv'
                        writetable(T, filePath, 'WriteVariableNames', true);

                    case '.txt'
                        writetable(T, filePath, 'Delimiter', '\t', 'WriteVariableNames', true);

                    otherwise
                        error('Unsupported file format.');
                end

            catch ME
                uialert(app.HDF5AnalysisAppUIFigure, ME.message, 'Export Error');
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create HDF5AnalysisAppUIFigure and hide until all components are created
            app.HDF5AnalysisAppUIFigure = uifigure('Visible', 'off');
            app.HDF5AnalysisAppUIFigure.Position = [100 100 1257 472];
            app.HDF5AnalysisAppUIFigure.Name = 'HDF5 Analysis App';

            % Create UIAxes
            app.UIAxes = uiaxes(app.HDF5AnalysisAppUIFigure);
            title(app.UIAxes, 'Title')
            xlabel(app.UIAxes, 'X')
            ylabel(app.UIAxes, 'Y')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.Position = [573 20 318 434];

            % Create UIAxes2
            app.UIAxes2 = uiaxes(app.HDF5AnalysisAppUIFigure);
            title(app.UIAxes2, 'Title')
            xlabel(app.UIAxes2, 'X')
            ylabel(app.UIAxes2, 'Y')
            zlabel(app.UIAxes2, 'Z')
            app.UIAxes2.Position = [901 20 318 434];

            % Create FilenameEditFieldLabel
            app.FilenameEditFieldLabel = uilabel(app.HDF5AnalysisAppUIFigure);
            app.FilenameEditFieldLabel.HorizontalAlignment = 'right';
            app.FilenameEditFieldLabel.Position = [20 406 58 22];
            app.FilenameEditFieldLabel.Text = 'File name';

            % Create FilenameEditField
            app.FilenameEditField = uieditfield(app.HDF5AnalysisAppUIFigure, 'text');
            app.FilenameEditField.Position = [93 406 459 22];

            % Create GetfileButton
            app.GetfileButton = uibutton(app.HDF5AnalysisAppUIFigure, 'push');
            app.GetfileButton.ButtonPushedFcn = createCallbackFcn(app, @GetfileButtonPushed, true);
            app.GetfileButton.BackgroundColor = [0.0745 0.6235 1];
            app.GetfileButton.Position = [20 436 100 23];
            app.GetfileButton.Text = 'Get file';

            % Create UITable1
            app.UITable1 = uitable(app.HDF5AnalysisAppUIFigure);
            app.UITable1.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            app.UITable1.RowName = {};
            app.UITable1.Position = [25 137 527 230];

            % Create mzEditFieldLabel
            app.mzEditFieldLabel = uilabel(app.HDF5AnalysisAppUIFigure);
            app.mzEditFieldLabel.HorizontalAlignment = 'right';
            app.mzEditFieldLabel.Position = [139 437 25 22];
            app.mzEditFieldLabel.Text = 'm/z';

            % Create mzEditField
            app.mzEditField = uieditfield(app.HDF5AnalysisAppUIFigure, 'numeric');
            app.mzEditField.ValueDisplayFormat = '%.3f';
            app.mzEditField.Position = [179 437 100 22];
            app.mzEditField.Value = 137.38;

            % Create UITable2
            app.UITable2 = uitable(app.HDF5AnalysisAppUIFigure);
            app.UITable2.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            app.UITable2.RowName = {};
            app.UITable2.Position = [24 7 528 99];

            % Create ExportTofDataButton
            app.ExportTofDataButton = uibutton(app.HDF5AnalysisAppUIFigure, 'push');
            app.ExportTofDataButton.ButtonPushedFcn = createCallbackFcn(app, @ExportTofDataButtonPushed, true);
            app.ExportTofDataButton.Position = [119 374 100 23];
            app.ExportTofDataButton.Text = 'Export TofData';

            % Create ExportSumDataButton
            app.ExportSumDataButton = uibutton(app.HDF5AnalysisAppUIFigure, 'push');
            app.ExportSumDataButton.ButtonPushedFcn = createCallbackFcn(app, @ExportSumDataButtonPushed, true);
            app.ExportSumDataButton.Position = [212 105 103 23];
            app.ExportSumDataButton.Text = 'Export SumData';

            % Create NeighbourmQLabel
            app.NeighbourmQLabel = uilabel(app.HDF5AnalysisAppUIFigure);
            app.NeighbourmQLabel.HorizontalAlignment = 'right';
            app.NeighbourmQLabel.Position = [297 433 112 30];
            app.NeighbourmQLabel.Text = 'Neighbour m/z (+/-)';

            % Create NeighbourmzEditField
            app.NeighbourmzEditField = uieditfield(app.HDF5AnalysisAppUIFigure, 'numeric');
            app.NeighbourmzEditField.ValueDisplayFormat = '%.3f';
            app.NeighbourmzEditField.Position = [425 437 123 22];
            app.NeighbourmzEditField.Value = 0.1;

            % Create Table1TofDataLabel
            app.Table1TofDataLabel = uilabel(app.HDF5AnalysisAppUIFigure);
            app.Table1TofDataLabel.Position = [25 374 95 22];
            app.Table1TofDataLabel.Text = 'Table 1. Tof Data';

            % Create Table2SumaryofSpectraldataLabel
            app.Table2SumaryofSpectraldataLabel = uilabel(app.HDF5AnalysisAppUIFigure);
            app.Table2SumaryofSpectraldataLabel.Position = [25 111 182 22];
            app.Table2SumaryofSpectraldataLabel.Text = 'Table 2. Sumary of Spectral data ';

            % Show the figure after all components are created
            app.HDF5AnalysisAppUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = HDF5_Analysis_V1_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.HDF5AnalysisAppUIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.HDF5AnalysisAppUIFigure)
        end
    end
end