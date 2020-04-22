using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using Microsoft.Azure.Management.DataFactory;
using Microsoft.Rest;
using Microsoft.Azure.Management.DataFactory.Models;

namespace GetErrorDetails
{
    public static class GetActivityErrorDetails
    {
        [FunctionName("GetActivityErrorDetails")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,
            ILogger log)
        {
            log.LogInformation("C# HTTP trigger function processed a request.");

            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            dynamic inputData = JsonConvert.DeserializeObject(requestBody);

            string tenantId = inputData?.tenantId;
            string applicationId = inputData?.applicationId;
            string authenticationKey = inputData?.authenticationKey;
            string subscriptionId = inputData?.subscriptionId;
            string resourceGroup = inputData?.resourceGroup;
            string factoryName = inputData?.factoryName;
            string pipelineName = inputData?.pipelineName;
            string runId = inputData?.runId;

            //Check body for values
            if (
                tenantId == null ||
                applicationId == null ||
                authenticationKey == null ||
                subscriptionId == null ||
                resourceGroup == null ||
                factoryName == null ||
                pipelineName == null ||
                runId == null
                )
            {
                return new BadRequestObjectResult("Invalid request body, value missing.");
            }

            //Create a data factory management client
            var context = new AuthenticationContext("https://login.windows.net/" + tenantId);
            ClientCredential cc = new ClientCredential(applicationId, authenticationKey);
            AuthenticationResult result = context.AcquireTokenAsync("https://management.azure.com/", cc).Result;
            ServiceClientCredentials cred = new TokenCredentials(result.AccessToken);
            var client = new DataFactoryManagementClient(cred)
            {
                SubscriptionId = subscriptionId
            };

            //Get pipeline details
            int daysOfRuns = 7; //max duration for mandatory RunFilterParameters
            DateTime today = DateTime.Now;
            DateTime lastWeek = DateTime.Now.AddDays(-daysOfRuns);

            PipelineRun pipelineRun;
            pipelineRun = client.PipelineRuns.Get(resourceGroup, factoryName, runId);

            RunFilterParameters filterParams = new RunFilterParameters(lastWeek, today);
            ActivityRunsQueryResponse queryResponse = client.ActivityRuns.QueryByPipelineRun(
                resourceGroup, factoryName, runId, filterParams);

            //Create initial output content
            dynamic outputValues = new JObject();

            outputValues.PipelineName = pipelineName;
            outputValues.PipelineStatus = pipelineRun.Status;
            outputValues.RunId = runId;
            outputValues.ResponseCount = queryResponse.Value.Count;
            outputValues.ResponseErrorCount = 0;
            outputValues.Errors = new JArray();
            JObject errorDetails;
            
            log.LogInformation("Pipeline status: " + pipelineRun.Status);
            log.LogInformation("Activities found in pipeline response: " + queryResponse.Value.Count.ToString());

            //Loop over activities in pipeline run
            foreach (var activity in queryResponse.Value)
            {
                if (String.IsNullOrEmpty(activity.Error.ToString()))
                {
                    continue; //just incase
                }

                //Parse error output to customise output
                dynamic outputData = JsonConvert.DeserializeObject(activity.Error.ToString());
                
                string errorCode = outputData?.errorCode;
                string errorType = outputData?.failureType;
                string errorMessage = outputData?.message;

                //Get output details
                if (!String.IsNullOrEmpty(errorCode))
                {
                    log.LogInformation("Activity name: " + activity.ActivityName);
                    log.LogInformation("Activity type: " + activity.ActivityType);
                    log.LogInformation("Error message: " + errorMessage);

                    outputValues.ResponseErrorCount += 1;

                    //Construct custom error information block
                    errorDetails = JObject.Parse("{ \"ActivityName\": \"" + activity.ActivityName +
                                    "\", \"ActivityType\": \"" + activity.ActivityType +
                                    "\", \"ErrorCode\": \"" + errorCode +
                                    "\", \"ErrorType\": \"" + errorType +
                                    "\", \"ErrorMessage\": \"" + errorMessage +
                                    "\" }");

                    outputValues.Errors.Add(errorDetails);
                }
            }
            return new OkObjectResult(outputValues);
        }
    }
}
