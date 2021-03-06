/****** Object:  Table [procfwk].[ProcessingStageDetails]    Script Date: 19/02/2020 19:10:32 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [procfwk].[ProcessingStageDetails](
	[StageId] [int] IDENTITY(1,1) NOT NULL,
	[StageName] [varchar](225) NOT NULL,
	[StageDescription] [varchar](4000) NULL,
	[Enabled] [bit] NOT NULL,
 CONSTRAINT [PK_ProcessStageDetails] PRIMARY KEY CLUSTERED 
(
	[StageId] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [procfwk].[ProcessingStageDetails] ADD  CONSTRAINT [DF_ProcessStageDetails_Enabled]  DEFAULT ((1)) FOR [Enabled]
GO
