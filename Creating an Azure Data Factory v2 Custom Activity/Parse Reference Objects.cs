if (File.Exists(workingDir + "\\" + linkedServiceFile))
{
	linkedServices = JsonConvert.DeserializeObject(File.ReadAllText(workingDir + "\\" + linkedServiceFile));

	int links = linkedServices.Count;
	for (int i = 0; i < links; i++)
	{
		if (linkedServices[i].properties.type.ToString() == "AzureDataLakeStore" && keyType == null)
		{
			dataLakeStoreUri = linkedServices[i].properties.typeProperties.dataLakeStoreUri.ToString();
			servicePrincipalId = linkedServices[i].properties.typeProperties.servicePrincipalId.ToString();
			servicePrincipalKey = linkedServices[i].properties.typeProperties.servicePrincipalKey.ToString();
			tenantId = linkedServices[i].properties.typeProperties.tenant.ToString();
		}
	}
}