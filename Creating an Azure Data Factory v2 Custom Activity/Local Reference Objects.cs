//batch variables
//https://docs.microsoft.com/en-us/azure/batch/batch-compute-node-environment-variables
            
string workingDir = Environment.GetEnvironmentVariable("AZ_BATCH_TASK_WORKING_DIR");
string nodeSharedDir = Environment.GetEnvironmentVariable("AZ_BATCH_NODE_SHARED_DIR");

//local paths
string path = Directory.GetCurrentDirectory();

//for local debugging:
if (workingDir == null)
{
    workingDir = Path.GetFullPath(Path.Combine(path, @"..\..\")) + "ReferenceObjects";
}
if (nodeSharedDir == null)
{
    nodeSharedDir = Path.GetFullPath(Path.Combine(path, @"..\..\")) + "Shared";
}