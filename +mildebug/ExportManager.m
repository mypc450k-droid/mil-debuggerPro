classdef ExportManager < handle
    methods
        function writeHTML(~,html,filePath)
            fid=fopen(filePath,'w');
            if fid<0, error('MILDebuggerPro:Export','Cannot open output file.'); end
            c=onCleanup(@() fclose(fid)); %#ok<NASGU>
            fwrite(fid,html,'char');
        end
    end
end
