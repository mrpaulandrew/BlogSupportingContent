using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using Microsoft.Rest;
using Microsoft.Azure.Management.DataFactory;
using Microsoft.Azure.Management.DataFactory.Models;
using System.Linq;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;

namespace PipelineStatusChecker
{
    public static class GetStatusByNameOnly
    {
        /// <summary>
        /// Gets the status of a data factory pipeline by name assuming the
        /// pipeline was executed within a recent time period.
        /// </summary>
        [FunctionName("GetStatusByNameOnly")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,
            ILogger log)
        {
            log.LogInformation("C# HTTP trigger function processed a request.");

            //Get body values
            string tenantId = req.Query["tenantId"];
            string applicationId = req.Query["applicationId"];
            string authenticationKey = req.Query["authenticationKey"];
            string subscriptionId = req.Query["subscriptionId"];
            string resourceGroup = req.Query["resourceGroup"];
            string factoryName = req.Query["factoryName"];
            string pipelineName = req.Query["pipelineName"];

            int daysOfRuns = int.Parse(Environment.GetEnvironmentVariable("DefaultDaysForPipelineRuns"));

            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            dynamic data = JsonConvert.DeserializeObject(requestBody);

            tenantId = tenantId ?? data?.tenantId;
            applicationId = applicationId ?? data?.applicationId;
            authenticationKey = authenticationKey ?? data?.authenticationKey;
            subscriptionId = subscriptionId ?? data?.subscriptionId;
            resourceGroup = resourceGroup ?? data?.resourceGroup;
            factoryName = factoryName ?? data?.factoryName;
            pipelineName = pipelineName ?? data?.pipelineName;

            //Check body for values
            if (
                tenantId == null ||
                applicationId == null ||
                authenticationKey == null ||
                subscriptionId == null ||
                factoryName == null || 
                pipelineName == null
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

            //Get pipeline status
            PipelineRun pipelineRuns; //used to find latest pipeline run id
            PipelineRun pipelineRun;  //used to get the status of the last pipeline
            string pipelineStatus = String.Empty;
            string runId = String.Empty;
            string outputString;
            DateTime today = DateTime.Now;
            DateTime lastWeek = DateTime.Now.AddDays(-daysOfRuns);

            /*
            * https://docs.microsoft.com/en-us/rest/api/datafactory/pipelineruns/querybyfactory#runqueryfilteroperand
            */

            //Query data factory for pipeline runs
            IList<string> pipelineList = new List<string> { pipelineName };
            IList<RunQueryFilter> moreParams = new List<RunQueryFilter>();

            moreParams.Add(new RunQueryFilter
            {
                Operand = RunQueryFilterOperand.PipelineName,
                OperatorProperty = RunQueryFilterOperator.Equals,
                Values = pipelineList
            });

            RunFilterParameters filterParams = new RunFilterParameters(lastWeek, today, null, moreParams, null);

            var requiredRuns = client.PipelineRuns.QueryByFactory(resourceGroup, factoryName, filterParams);
            var enumerator = requiredRuns.Value.GetEnumerator();
            
            //Get latest run id
            for (bool hasMoreRuns = enumerator.MoveNext(); hasMoreRuns;)
            {
                pipelineRuns = enumerator.Current;
                hasMoreRuns = enumerator.MoveNext();

                if(!hasMoreRuns && pipelineRuns.PipelineName == pipelineName) 
                {
                    //Get status for run id
                    runId = pipelineRuns.RunId;
                    pipelineStatus = client.PipelineRuns.Get(resourceGroup, factoryName, runId).Status;
                }
            }

            //Prepare output
            outputString = "{ \"PipelineName\": \"" + pipelineName + "\", \"RunIdUsed\": \"" + runId + "\", \"Status\": \"" + pipelineStatus + "\" }";
            JObject json = JObject.Parse(outputString);

            return new OkObjectResult(json);
        }
    }

    public static class GetStatusByNameAndRunId
    {
        /// <summary>
        /// Gets the status of a data factory pipeline by name and execution run id.
        /// </summary>
        [FunctionName("GetStatusByNameAndRunId")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,
            ILogger log)
        {
            log.LogInformation("C# HTTP trigger function processed a request.");

            //Get body values
            string tenantId = req.Query["tenantId"];
            string applicationId = req.Query["applicationId"];
            string authenticationKey = req.Query["authenticationKey"];
            string subscriptionId = req.Query["subscriptionId"];
            string resourceGroup = req.Query["resourceGroup"];
            string factoryName = req.Query["factoryName"];
            string pipelineName = req.Query["pipelineName"];
            string runId = req.Query["runId"];

            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            dynamic data = JsonConvert.DeserializeObject(requestBody);

            tenantId = tenantId ?? data?.tenantId;
            applicationId = applicationId ?? data?.applicationId;
            authenticationKey = authenticationKey ?? data?.authenticationKey;
            subscriptionId = subscriptionId ?? data?.subscriptionId;
            resourceGroup = resourceGroup ?? data?.resourceGroup;
            factoryName = factoryName ?? data?.factoryName;
            pipelineName = pipelineName ?? data?.pipelineName;
            runId = runId ?? data?.runId;

            //Check body for values
            if (
                tenantId == null ||
                applicationId == null ||
                authenticationKey == null ||
                subscriptionId == null ||
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
            AuthenticationResult result = context.AcquireTokenAsync(
                "https://management.azure.com/", cc).Result;
            ServiceClientCredentials cred = new TokenCredentials(result.AccessToken);
            var client = new DataFactoryManagementClient(cred)
            {
                SubscriptionId = subscriptionId
            };

            //Get pipeline status with provided run id
            PipelineRun pipelineRun;
            string pipelineStatus = String.Empty;
            string outputString;

            pipelineRun = client.PipelineRuns.Get(resourceGroup, factoryName, runId);
            pipelineStatus = pipelineRun.Status;

            //Prepare output
            outputString = "{ \"PipelineName\": \"" + pipelineName + "\", \"RunIdUsed\": \"" + runId + "\", \"Status\": \"" + pipelineRun.Status + "\" }";
            JObject json = JObject.Parse(outputString);

            return new OkObjectResult(json);
        }
    }

    public static class GetAndWaitForStatusByName
    {
        /// <summary>
        /// Gets the status of a data factory pipeline by name assuming the
        /// pipeline was executed within a recent time period.
        /// Waits until the pipeline returns causing the function to block its caller.
        /// </summary>
        [FunctionName("GetAndWaitForStatusByName")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,
            ILogger log)
        {
            log.LogInformation("C# HTTP trigger function processed a request.");

            string tenantId = req.Query["tenantId"];
            string applicationId = req.Query["applicationId"];
            string authenticationKey = req.Query["authenticationKey"];
            string subscriptionId = req.Query["subscriptionId"];
            string resourceGroup = req.Query["resourceGroup"];
            string factoryName = req.Query["factoryName"];
            string pipelineName = req.Query["pipelineName"];

            int daysOfRuns = int.Parse(Environment.GetEnvironmentVariable("DefaultDaysForPipelineRuns"));

            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            dynamic data = JsonConvert.DeserializeObject(requestBody);

            tenantId = tenantId ?? data?.tenantId;
            applicationId = applicationId ?? data?.applicationId;
            authenticationKey = authenticationKey ?? data?.authenticationKey;
            subscriptionId = subscriptionId ?? data?.subscriptionId;
            resourceGroup = resourceGroup ?? data?.resourceGroup;
            factoryName = factoryName ?? data?.factoryName;
            pipelineName = pipelineName ?? data?.pipelineName;

            if (
                tenantId == null ||
                applicationId == null ||
                authenticationKey == null ||
                subscriptionId == null ||
                factoryName == null ||
                pipelineName == null
                )
            {
                return new BadRequestObjectResult("Invalid request body, value missing.");
            }

            // Authenticate and create a data factory management client
            var context = new AuthenticationContext("https://login.windows.net/" + tenantId);
            ClientCredential cc = new ClientCredential(applicationId, authenticationKey);
            AuthenticationResult result = context.AcquireTokenAsync(
                "https://management.azure.com/", cc).Result;
            ServiceClientCredentials cred = new TokenCredentials(result.AccessToken);
            var client = new DataFactoryManagementClient(cred)
            {
                SubscriptionId = subscriptionId
            };

            //Get pipeline status
            PipelineRun pipelineRuns; //used to find latest pipeline run id
            PipelineRun pipelineRun;  //used to get the status of the last pipeline
            ActivityRunsQueryResponse queryResponse; //used if not successful
            string runId = String.Empty;
            string errorDetails = String.Empty;
            string outputString;
            DateTime today = DateTime.Now;
            DateTime lastWeek = DateTime.Now.AddDays(-daysOfRuns);

            /*
            * https://docs.microsoft.com/en-us/rest/api/datafactory/pipelineruns/querybyfactory#runqueryfilteroperand
            */

            //Query data factory for pipeline runs
            IList<string> pipelineList = new List<string> { pipelineName };
            IList<RunQueryFilter> moreParams = new List<RunQueryFilter>();

            moreParams.Add(new RunQueryFilter
            {
                Operand = RunQueryFilterOperand.PipelineName,
                OperatorProperty = RunQueryFilterOperator.Equals,
                Values = pipelineList
            });

            RunFilterParameters filterParams = new RunFilterParameters(lastWeek, today, null, moreParams, null);

            var requiredRuns = client.PipelineRuns.QueryByFactory(resourceGroup, factoryName, filterParams);
            var enumerator = requiredRuns.Value.GetEnumerator();

            //Get latest run id
            for (bool hasMoreRuns = enumerator.MoveNext(); hasMoreRuns;)
            {
                pipelineRuns = enumerator.Current;
                hasMoreRuns = enumerator.MoveNext();

                if (!hasMoreRuns && pipelineRuns.PipelineName == pipelineName) //&& just incase, filter above should deal with this
                {
                    //Get run id
                    runId = pipelineRuns.RunId;
                }
            }

            //Wait for success or fail
            while (true)
            {
                pipelineRun = client.PipelineRuns.Get(resourceGroup, factoryName, runId);

                //Console.WriteLine("Status: " + pipelineRun.Status);
                if (pipelineRun.Status == "InProgress" || pipelineRun.Status == "Queued")
                {
                    System.Threading.Thread.Sleep(15000);
                }
                else
                {
                    break;
                }
            }

            //Get error details
            if (pipelineRun.Status != "Succeeded")
            {
                // Check the pipeline if it wasn't successful
                RunFilterParameters filterParamsForError = new RunFilterParameters(lastWeek, today);
                queryResponse = client.ActivityRuns.QueryByPipelineRun(resourceGroup, factoryName, runId, filterParamsForError);
                errorDetails = queryResponse.Value.First().Error.ToString();
            }

            //Prepare output
            outputString = "{ \"PipelineName\": \"" + pipelineName + "\", \"RunIdUsed\": \"" + runId + "\", \"Status\": \"" + pipelineRun.Status + "\" }";
            JObject json = JObject.Parse(outputString);

            return pipelineRun.Status == "Succeeded" 
                ? (ActionResult)new OkObjectResult(json)
                : new BadRequestObjectResult($"{errorDetails}");
        }
    }
}
