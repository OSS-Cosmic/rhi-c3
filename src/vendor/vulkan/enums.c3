// Core enum and flag types alias c3lang/vendor's vulkan.c3l package. Types and
// values outside its core Vulkan 1.3 set remain local for extension support.
module vk;
import vulkan::vk;

// Enums
alias AttachmentLoadOp = vulkan::vk::VkAttachmentLoadOp;

alias AttachmentStoreOp = vulkan::vk::VkAttachmentStoreOp;

alias BlendFactor = vulkan::vk::VkBlendFactor;

alias BlendOp = vulkan::vk::VkBlendOp;

alias BorderColor = vulkan::vk::VkBorderColor;

alias PipelineCacheHeaderVersion = vulkan::vk::VkPipelineCacheHeaderVersion;

alias ComponentSwizzle = vulkan::vk::VkComponentSwizzle;

alias CommandBufferLevel = vulkan::vk::VkCommandBufferLevel;

alias CompareOp = vulkan::vk::VkCompareOp;

alias DescriptorType = vulkan::vk::VkDescriptorType;

alias DynamicState = vulkan::vk::VkDynamicState;

alias PolygonMode = vulkan::vk::VkPolygonMode;

alias Format = vulkan::vk::VkFormat;

alias FrontFace = vulkan::vk::VkFrontFace;

alias ImageLayout = vulkan::vk::VkImageLayout;

alias ImageTiling = vulkan::vk::VkImageTiling;

alias ImageType = vulkan::vk::VkImageType;

alias ImageViewType = vulkan::vk::VkImageViewType;

constdef IndirectCommandsTokenTypeEXT : int
{
	EXECUTION_SET            = 0,
	PUSH_CONSTANT            = 1,
	SEQUENCE_INDEX           = 2,
	INDEX_BUFFER             = 3,
	VERTEX_BUFFER            = 4,
	DRAW_INDEXED             = 5,
	DRAW                     = 6,
	DRAW_INDEXED_COUNT       = 7,
	DRAW_COUNT               = 8,
	DISPATCH                 = 9,
	PUSH_DATA                = 1000135000,
	PUSH_DATA_SEQUENCE_INDEX = 1000135001,
	DRAW_MESH_TASKS_NV       = 1000202002,
	DRAW_MESH_TASKS_COUNT_NV = 1000202003,
	DRAW_MESH_TASKS          = 1000328000,
	DRAW_MESH_TASKS_COUNT    = 1000328001,
	TRACE_RAYS2              = 1000386004,
}

alias SharingMode = vulkan::vk::VkSharingMode;

alias IndexType = vulkan::vk::VkIndexType;

alias LogicOp = vulkan::vk::VkLogicOp;

alias PhysicalDeviceType = vulkan::vk::VkPhysicalDeviceType;

alias PipelineBindPoint = vulkan::vk::VkPipelineBindPoint;

alias PrimitiveTopology = vulkan::vk::VkPrimitiveTopology;

alias QueryType = vulkan::vk::VkQueryType;

alias SubpassContents = vulkan::vk::VkSubpassContents;

alias Result = vulkan::vk::VkResult;

alias StencilOp = vulkan::vk::VkStencilOp;

alias StructureType = vulkan::vk::VkStructureType;

alias SystemAllocationScope = vulkan::vk::VkSystemAllocationScope;

alias InternalAllocationType = vulkan::vk::VkInternalAllocationType;

alias SamplerAddressMode = vulkan::vk::VkSamplerAddressMode;

alias Filter = vulkan::vk::VkFilter;

alias SamplerMipmapMode = vulkan::vk::VkSamplerMipmapMode;

alias VertexInputRate = vulkan::vk::VkVertexInputRate;

constdef ClusterAccelerationStructureTypeNV : int
{
	CLUSTERS_BOTTOM_LEVEL     = 0,
	TRIANGLE_CLUSTER          = 1,
	TRIANGLE_CLUSTER_TEMPLATE = 2,
}

constdef ClusterAccelerationStructureOpTypeNV : int
{
	MOVE_OBJECTS                    = 0,
	BUILD_CLUSTERS_BOTTOM_LEVEL     = 1,
	BUILD_TRIANGLE_CLUSTER          = 2,
	BUILD_TRIANGLE_CLUSTER_TEMPLATE = 3,
	INSTANTIATE_TRIANGLE_CLUSTER    = 4,
	GET_CLUSTER_TEMPLATE_INDICES    = 5,
}

constdef ClusterAccelerationStructureOpModeNV : int
{
	IMPLICIT_DESTINATIONS = 0,
	EXPLICIT_DESTINATIONS = 1,
	COMPUTE_SIZES         = 2,
}

alias ObjectType = vulkan::vk::VkObjectType;

constdef RayTracingInvocationReorderModeEXT : int
{
	NONE       = 0,
	REORDER    = 1,
	NONE_NV    = 0,
	REORDER_NV = 1,
}

constdef IndirectCommandsTokenTypeNV : int
{
	SHADER_GROUP    = 0,
	STATE_FLAGS     = 1,
	INDEX_BUFFER    = 2,
	VERTEX_BUFFER   = 3,
	PUSH_CONSTANT   = 4,
	DRAW_INDEXED    = 5,
	DRAW            = 6,
	DRAW_TASKS      = 7,
	PUSH_DATA       = 1000135000,
	DRAW_MESH_TASKS = 1000328000,
	PIPELINE        = 1000428003,
	DISPATCH        = 1000428004,
}

alias DescriptorUpdateTemplateType = vulkan::vk::VkDescriptorUpdateTemplateType;

constdef ViewportCoordinateSwizzleNV : int
{
	POSITIVE_X = 0,
	NEGATIVE_X = 1,
	POSITIVE_Y = 2,
	NEGATIVE_Y = 3,
	POSITIVE_Z = 4,
	NEGATIVE_Z = 5,
	POSITIVE_W = 6,
	NEGATIVE_W = 7,
}

constdef DiscardRectangleModeEXT : int
{
	INCLUSIVE = 0,
	EXCLUSIVE = 1,
}

alias PointClippingBehavior = vulkan::vk::VkPointClippingBehavior;

constdef CoverageModulationModeNV : int
{
	NONE  = 0,
	RGB   = 1,
	ALPHA = 2,
	RGBA  = 3,
}

constdef CoverageReductionModeNV : int
{
	MERGE    = 0,
	TRUNCATE = 1,
}

constdef ValidationCacheHeaderVersionEXT : int
{
	ONE = 1,
}

constdef ShaderInfoTypeAMD : int
{
	STATISTICS  = 0,
	BINARY      = 1,
	DISASSEMBLY = 2,
}

constdef QueueGlobalPriority : int
{
	LOW          = 128,
	MEDIUM       = 256,
	HIGH         = 512,
	REALTIME     = 1024,
	LOW_EXT      = 128,
	MEDIUM_EXT   = 256,
	HIGH_EXT     = 512,
	REALTIME_EXT = 1024,
	LOW_KHR      = 128,
	MEDIUM_KHR   = 256,
	HIGH_KHR     = 512,
	REALTIME_KHR = 1024,
}

constdef TimeDomainKHR : int
{
	DEVICE                        = 0,
	CLOCK_MONOTONIC               = 1,
	CLOCK_MONOTONIC_RAW           = 2,
	QUERY_PERFORMANCE_COUNTER     = 3,
	DEVICE_EXT                    = 0,
	CLOCK_MONOTONIC_EXT           = 1,
	CLOCK_MONOTONIC_RAW_EXT       = 2,
	QUERY_PERFORMANCE_COUNTER_EXT = 3,
	PRESENT_STAGE_LOCAL_EXT       = 1000208000,
	SWAPCHAIN_LOCAL_EXT           = 1000208001,
}

constdef ConservativeRasterizationModeEXT : int
{
	DISABLED      = 0,
	OVERESTIMATE  = 1,
	UNDERESTIMATE = 2,
}

alias SemaphoreType = vulkan::vk::VkSemaphoreType;

constdef BuildAccelerationStructureModeKHR : int
{
	BUILD  = 0,
	UPDATE = 1,
}

constdef CopyAccelerationStructureModeKHR : int
{
	CLONE       = 0,
	COMPACT     = 1,
	SERIALIZE   = 2,
	DESERIALIZE = 3,
	CLONE_NV    = 0,
	COMPACT_NV  = 1,
}

constdef AccelerationStructureTypeKHR : int
{
	TOP_LEVEL       = 0,
	BOTTOM_LEVEL    = 1,
	GENERIC         = 2,
	TOP_LEVEL_NV    = 0,
	BOTTOM_LEVEL_NV = 1,
}

constdef GeometryTypeKHR : int
{
	TRIANGLES               = 0,
	AABBS                   = 1,
	INSTANCES               = 2,
	TRIANGLES_NV            = 0,
	AABBS_NV                = 1,
	SPHERES_NV              = 1000429004,
	LINEAR_SWEPT_SPHERES_NV = 1000429005,
}

constdef RayTracingShaderGroupTypeKHR : int
{
	GENERAL                 = 0,
	TRIANGLES_HIT_GROUP     = 1,
	PROCEDURAL_HIT_GROUP    = 2,
	GENERAL_NV              = 0,
	TRIANGLES_HIT_GROUP_NV  = 1,
	PROCEDURAL_HIT_GROUP_NV = 2,
}

constdef AccelerationStructureMemoryRequirementsTypeNV : int
{
	OBJECT         = 0,
	BUILD_SCRATCH  = 1,
	UPDATE_SCRATCH = 2,
}

constdef AccelerationStructureBuildTypeKHR : int
{
	HOST           = 0,
	DEVICE         = 1,
	HOST_OR_DEVICE = 2,
}

constdef AccelerationStructureCompatibilityKHR : int
{
	COMPATIBLE   = 0,
	INCOMPATIBLE = 1,
}

constdef RayTracingLssIndexingModeNV : int
{
	LIST       = 0,
	SUCCESSIVE = 1,
}

constdef RayTracingLssPrimitiveEndCapsModeNV : int
{
	NONE    = 0,
	CHAINED = 1,
}

constdef ShaderGroupShaderKHR : int
{
	GENERAL      = 0,
	CLOSEST_HIT  = 1,
	ANY_HIT      = 2,
	INTERSECTION = 3,
}

constdef MemoryOverallocationBehaviorAMD : int
{
	DEFAULT    = 0,
	ALLOWED    = 1,
	DISALLOWED = 2,
}

constdef PerformanceCounterScopeKHR : int
{
	COMMAND_BUFFER             = 0,
	RENDER_PASS                = 1,
	COMMAND                    = 2,
	QUERY_SCOPE_COMMAND_BUFFER = 0,
	QUERY_SCOPE_RENDER_PASS    = 1,
	QUERY_SCOPE_COMMAND        = 2,
}

constdef PerformanceCounterUnitKHR : int
{
	GENERIC          = 0,
	PERCENTAGE       = 1,
	NANOSECONDS      = 2,
	BYTES            = 3,
	BYTES_PER_SECOND = 4,
	KELVIN           = 5,
	WATTS            = 6,
	VOLTS            = 7,
	AMPS             = 8,
	HERTZ            = 9,
	CYCLES           = 10,
}

constdef PerformanceCounterStorageKHR : int
{
	INT32   = 0,
	INT64   = 1,
	UINT32  = 2,
	UINT64  = 3,
	FLOAT32 = 4,
	FLOAT64 = 5,
}

constdef PerformanceConfigurationTypeINTEL : int
{
	COMMAND_QUEUE_METRICS_DISCOVERY_ACTIVATED = 0,
}

constdef QueryPoolSamplingModeINTEL : int
{
	MANUAL = 0,
}

constdef PerformanceOverrideTypeINTEL : int
{
	NULL_HARDWARE    = 0,
	FLUSH_GPU_CACHES = 1,
}

constdef PerformanceParameterTypeINTEL : int
{
	HW_COUNTERS_SUPPORTED    = 0,
	STREAM_MARKER_VALID_BITS = 1,
}

constdef PerformanceValueTypeINTEL : int
{
	UINT32 = 0,
	UINT64 = 1,
	FLOAT  = 2,
	BOOL   = 3,
	STRING = 4,
}

constdef LineRasterizationMode : int
{
	DEFAULT                = 0,
	RECTANGULAR            = 1,
	BRESENHAM              = 2,
	RECTANGULAR_SMOOTH     = 3,
	DEFAULT_EXT            = 0,
	RECTANGULAR_EXT        = 1,
	BRESENHAM_EXT          = 2,
	RECTANGULAR_SMOOTH_EXT = 3,
	DEFAULT_KHR            = 0,
	RECTANGULAR_KHR        = 1,
	BRESENHAM_KHR          = 2,
	RECTANGULAR_SMOOTH_KHR = 3,
}

constdef FragmentShadingRateNV : int
{
	RATE_1_INVOCATION_PER_PIXEL      = 0,
	RATE_1_INVOCATION_PER_1X2_PIXELS = 1,
	RATE_1_INVOCATION_PER_2X1_PIXELS = 4,
	RATE_1_INVOCATION_PER_2X2_PIXELS = 5,
	RATE_1_INVOCATION_PER_2X4_PIXELS = 6,
	RATE_1_INVOCATION_PER_4X2_PIXELS = 9,
	RATE_1_INVOCATION_PER_4X4_PIXELS = 10,
	RATE_2_INVOCATIONS_PER_PIXEL     = 11,
	RATE_4_INVOCATIONS_PER_PIXEL     = 12,
	RATE_8_INVOCATIONS_PER_PIXEL     = 13,
	RATE_16_INVOCATIONS_PER_PIXEL    = 14,
	NO_INVOCATIONS                   = 15,
}

constdef FragmentShadingRateTypeNV : int
{
	FRAGMENT_SIZE = 0,
	ENUMS         = 1,
}

constdef SubpassMergeStatusEXT : int
{
	MERGED                                   = 0,
	DISALLOWED                               = 1,
	NOT_MERGED_SIDE_EFFECTS                  = 2,
	NOT_MERGED_SAMPLES_MISMATCH              = 3,
	NOT_MERGED_VIEWS_MISMATCH                = 4,
	NOT_MERGED_ALIASING                      = 5,
	NOT_MERGED_DEPENDENCIES                  = 6,
	NOT_MERGED_INCOMPATIBLE_INPUT_ATTACHMENT = 7,
	NOT_MERGED_TOO_MANY_ATTACHMENTS          = 8,
	NOT_MERGED_INSUFFICIENT_STORAGE          = 9,
	NOT_MERGED_DEPTH_STENCIL_COUNT           = 10,
	NOT_MERGED_RESOLVE_ATTACHMENT_REUSE      = 11,
	NOT_MERGED_SINGLE_SUBPASS                = 12,
	NOT_MERGED_UNSPECIFIED                   = 13,
}

constdef ProvokingVertexModeEXT : int
{
	FIRST_VERTEX = 0,
	LAST_VERTEX  = 1,
}

constdef PipelineRobustnessBufferBehavior : int
{
	DEVICE_DEFAULT             = 0,
	DISABLED                   = 1,
	ROBUST_BUFFER_ACCESS       = 2,
	ROBUST_BUFFER_ACCESS_2     = 3,
	DEVICE_DEFAULT_EXT         = 0,
	DISABLED_EXT               = 1,
	ROBUST_BUFFER_ACCESS_EXT   = 2,
	ROBUST_BUFFER_ACCESS_2_EXT = 3,
}

constdef PipelineRobustnessImageBehavior : int
{
	DEVICE_DEFAULT            = 0,
	DISABLED                  = 1,
	ROBUST_IMAGE_ACCESS       = 2,
	ROBUST_IMAGE_ACCESS_2     = 3,
	DEVICE_DEFAULT_EXT        = 0,
	DISABLED_EXT              = 1,
	ROBUST_IMAGE_ACCESS_EXT   = 2,
	ROBUST_IMAGE_ACCESS_2_EXT = 3,
}

constdef DeviceAddressBindingTypeEXT : int
{
	BIND   = 0,
	UNBIND = 1,
}

constdef MicromapTypeEXT : int
{
	OPACITY_MICROMAP = 0,
}

constdef BuildMicromapModeEXT : int
{
	BUILD = 0,
}

constdef CopyMicromapModeEXT : int
{
	CLONE       = 0,
	SERIALIZE   = 1,
	DESERIALIZE = 2,
	COMPACT     = 3,
}

constdef OpacityMicromapFormatEXT : int
{
	FORMAT_2_STATE = 1,
	FORMAT_4_STATE = 2,
}

constdef OpacityMicromapSpecialIndexEXT : int
{
	FULLY_TRANSPARENT                            = -1,
	FULLY_OPAQUE                                 = -2,
	FULLY_UNKNOWN_TRANSPARENT                    = -3,
	FULLY_UNKNOWN_OPAQUE                         = -4,
	CLUSTER_GEOMETRY_DISABLE_OPACITY_MICROMAP_NV = -5,
}

constdef DeviceFaultVendorBinaryHeaderVersionEXT : int
{
	ONE = 1,
}

constdef IndirectExecutionSetInfoTypeEXT : int
{
	PIPELINES      = 0,
	SHADER_OBJECTS = 1,
}

constdef DepthBiasRepresentationEXT : int
{
	LEAST_REPRESENTABLE_VALUE_FORMAT      = 0,
	LEAST_REPRESENTABLE_VALUE_FORCE_UNORM = 1,
	FLOAT                                 = 2,
}

constdef DirectDriverLoadingModeLUNARG : int
{
	EXCLUSIVE = 0,
	INCLUSIVE = 1,
}

constdef PartitionedAccelerationStructureOpTypeNV : int
{
	WRITE_INSTANCE              = 0,
	UPDATE_INSTANCE             = 1,
	WRITE_PARTITION_TRANSLATION = 2,
}

constdef AntiLagModeAMD : int
{
	DRIVER_CONTROL = 0,
	ON             = 1,
	OFF            = 2,
}

constdef AntiLagStageAMD : int
{
	INPUT   = 0,
	PRESENT = 1,
}

constdef ShaderCodeTypeEXT : int
{
	BINARY = 0,
	SPIRV  = 1,
}

constdef ScopeKHR : int
{
	DEVICE          = 1,
	WORKGROUP       = 2,
	SUBGROUP        = 3,
	QUEUE_FAMILY    = 5,
	DEVICE_NV       = 1,
	WORKGROUP_NV    = 2,
	SUBGROUP_NV     = 3,
	QUEUE_FAMILY_NV = 5,
}

constdef ComponentTypeKHR : int
{
	FLOAT16         = 0,
	FLOAT32         = 1,
	FLOAT64         = 2,
	SINT8           = 3,
	SINT16          = 4,
	SINT32          = 5,
	SINT64          = 6,
	UINT8           = 7,
	UINT16          = 8,
	UINT32          = 9,
	UINT64          = 10,
	BFLOAT16        = 1000141000,
	FLOAT16_NV      = 0,
	FLOAT32_NV      = 1,
	FLOAT64_NV      = 2,
	SINT8_NV        = 3,
	SINT16_NV       = 4,
	SINT32_NV       = 5,
	SINT64_NV       = 6,
	UINT8_NV        = 7,
	UINT16_NV       = 8,
	UINT32_NV       = 9,
	UINT64_NV       = 10,
	SINT8_PACKED_NV = 1000491000,
	UINT8_PACKED_NV = 1000491001,
	FLOAT_E4M3_NV   = 1000491002,
	FLOAT_E5M2_NV   = 1000491003,
	FLOAT8_E4M3_EXT = 1000491002,
	FLOAT8_E5M2_EXT = 1000491003,
}

constdef CubicFilterWeightsQCOM : int
{
	CATMULL_ROM           = 0,
	ZERO_TANGENT_CARDINAL = 1,
	B_SPLINE              = 2,
	MITCHELL_NETRAVALI    = 3,
}

constdef BlockMatchWindowCompareModeQCOM : int
{
	MIN = 0,
	MAX = 1,
}

constdef LayeredDriverUnderlyingApiMSFT : int
{
	NONE  = 0,
	D3D12 = 1,
}

constdef PhysicalDeviceLayeredApiKHR : int
{
	VULKAN   = 0,
	D3D12    = 1,
	METAL    = 2,
	OPENGL   = 3,
	OPENGLES = 4,
}

constdef DepthClampModeEXT : int
{
	VIEWPORT_RANGE     = 0,
	USER_DEFINED_RANGE = 1,
}

constdef CooperativeVectorMatrixLayoutNV : int
{
	ROW_MAJOR           = 0,
	COLUMN_MAJOR        = 1,
	INFERENCING_OPTIMAL = 2,
	TRAINING_OPTIMAL    = 3,
}

constdef TensorTilingARM : int
{
	OPTIMAL = 0,
	LINEAR  = 1,
}

constdef DataGraphPipelinePropertyARM : int
{
	CREATION_LOG = 0,
	IDENTIFIER   = 1,
}

constdef DataGraphPipelineSessionBindPointARM : int
{
	TRANSIENT = 0,
}

constdef DataGraphPipelineSessionBindPointTypeARM : int
{
	MEMORY = 0,
}

constdef PhysicalDeviceDataGraphProcessingEngineTypeARM : int
{
	DEFAULT      = 0,
	NEURAL_QCOM  = 1000629000,
	COMPUTE_QCOM = 1000629001,
}

constdef PhysicalDeviceDataGraphOperationTypeARM : int
{
	SPIRV_EXTENDED_INSTRUCTION_SET = 0,
	NEURAL_MODEL_QCOM              = 1000629000,
	BUILTIN_MODEL_QCOM             = 1000629001,
}

constdef DataGraphModelCacheTypeQCOM : int
{
	GENERIC_BINARY = 0,
}

constdef DescriptorMappingSourceEXT : int
{
	HEAP_WITH_CONSTANT_OFFSET      = 0,
	HEAP_WITH_PUSH_INDEX           = 1,
	HEAP_WITH_INDIRECT_INDEX       = 2,
	HEAP_WITH_INDIRECT_INDEX_ARRAY = 3,
	RESOURCE_HEAP_DATA             = 4,
	PUSH_DATA                      = 5,
	PUSH_ADDRESS                   = 6,
	INDIRECT_ADDRESS               = 7,
	HEAP_WITH_SHADER_RECORD_INDEX  = 8,
	SHADER_RECORD_DATA             = 9,
	SHADER_RECORD_ADDRESS          = 10,
}

constdef ColorSpaceKHR : int
{
	SRGB_NONLINEAR              = 0,
	COLORSPACE_SRGB_NONLINEAR   = 0,
	DISPLAY_P3_NONLINEAR_EXT    = 1000104001,
	EXTENDED_SRGB_LINEAR_EXT    = 1000104002,
	DISPLAY_P3_LINEAR_EXT       = 1000104003,
	DCI_P3_NONLINEAR_EXT        = 1000104004,
	BT709_LINEAR_EXT            = 1000104005,
	BT709_NONLINEAR_EXT         = 1000104006,
	BT2020_LINEAR_EXT           = 1000104007,
	HDR10_ST2084_EXT            = 1000104008,
	DOLBYVISION_EXT             = 1000104009,
	HDR10_HLG_EXT               = 1000104010,
	ADOBERGB_LINEAR_EXT         = 1000104011,
	ADOBERGB_NONLINEAR_EXT      = 1000104012,
	PASS_THROUGH_EXT            = 1000104013,
	EXTENDED_SRGB_NONLINEAR_EXT = 1000104014,
	DCI_P3_LINEAR_EXT           = 1000104003,
	DISPLAY_NATIVE_AMD          = 1000213000,
}

constdef PresentModeKHR : int
{
	IMMEDIATE                 = 0,
	MAILBOX                   = 1,
	FIFO                      = 2,
	FIFO_RELAXED              = 3,
	SHARED_DEMAND_REFRESH     = 1000111000,
	SHARED_CONTINUOUS_REFRESH = 1000111001,
	FIFO_LATEST_READY_EXT     = 1000361000,
	FIFO_LATEST_READY         = 1000361000,
}

constdef DisplaySurfaceStereoTypeNV : int
{
	NONE               = 0,
	ONBOARD_DIN        = 1,
	HDMI_3D            = 2,
	INBAND_DISPLAYPORT = 3,
}

constdef DebugReportObjectTypeEXT : int
{
	UNKNOWN                        = 0,
	INSTANCE                       = 1,
	PHYSICAL_DEVICE                = 2,
	DEVICE                         = 3,
	QUEUE                          = 4,
	SEMAPHORE                      = 5,
	COMMAND_BUFFER                 = 6,
	FENCE                          = 7,
	DEVICE_MEMORY                  = 8,
	BUFFER                         = 9,
	IMAGE                          = 10,
	EVENT                          = 11,
	QUERY_POOL                     = 12,
	BUFFER_VIEW                    = 13,
	IMAGE_VIEW                     = 14,
	SHADER_MODULE                  = 15,
	PIPELINE_CACHE                 = 16,
	PIPELINE_LAYOUT                = 17,
	RENDER_PASS                    = 18,
	PIPELINE                       = 19,
	DESCRIPTOR_SET_LAYOUT          = 20,
	SAMPLER                        = 21,
	DESCRIPTOR_POOL                = 22,
	DESCRIPTOR_SET                 = 23,
	FRAMEBUFFER                    = 24,
	COMMAND_POOL                   = 25,
	SURFACE_KHR                    = 26,
	SWAPCHAIN_KHR                  = 27,
	DEBUG_REPORT_CALLBACK_EXT      = 28,
	DEBUG_REPORT                   = 28,
	DISPLAY_KHR                    = 29,
	DISPLAY_MODE_KHR               = 30,
	VALIDATION_CACHE_EXT           = 33,
	VALIDATION_CACHE               = 33,
	SAMPLER_YCBCR_CONVERSION       = 1000156000,
	DESCRIPTOR_UPDATE_TEMPLATE     = 1000085000,
	CU_MODULE_NVX                  = 1000029000,
	CU_FUNCTION_NVX                = 1000029001,
	DESCRIPTOR_UPDATE_TEMPLATE_KHR = 1000085000,
	ACCELERATION_STRUCTURE_KHR     = 1000150000,
	SAMPLER_YCBCR_CONVERSION_KHR   = 1000156000,
	ACCELERATION_STRUCTURE_NV      = 1000165000,
}

constdef DeviceMemoryReportEventTypeEXT : int
{
	ALLOCATE          = 0,
	FREE              = 1,
	IMPORT            = 2,
	UNIMPORT          = 3,
	ALLOCATION_FAILED = 4,
}

constdef RasterizationOrderAMD : int
{
	STRICT  = 0,
	RELAXED = 1,
}

constdef ValidationCheckEXT : int
{
	ALL     = 0,
	SHADERS = 1,
}

constdef ValidationFeatureEnableEXT : int
{
	GPU_ASSISTED                      = 0,
	GPU_ASSISTED_RESERVE_BINDING_SLOT = 1,
	BEST_PRACTICES                    = 2,
	DEBUG_PRINTF                      = 3,
	SYNCHRONIZATION_VALIDATION        = 4,
}

constdef ValidationFeatureDisableEXT : int
{
	ALL                     = 0,
	SHADERS                 = 1,
	THREAD_SAFETY           = 2,
	API_PARAMETERS          = 3,
	OBJECT_LIFETIMES        = 4,
	CORE_CHECKS             = 5,
	UNIQUE_HANDLES          = 6,
	SHADER_VALIDATION_CACHE = 7,
}

constdef DisplayPowerStateEXT : int
{
	OFF     = 0,
	SUSPEND = 1,
	ON      = 2,
}

constdef DeviceEventTypeEXT : int
{
	DISPLAY_HOTPLUG = 0,
}

constdef DisplayEventTypeEXT : int
{
	FIRST_PIXEL_OUT = 0,
}

alias TessellationDomainOrigin = vulkan::vk::VkTessellationDomainOrigin;

alias SamplerYcbcrModelConversion = vulkan::vk::VkSamplerYcbcrModelConversion;

alias SamplerYcbcrRange = vulkan::vk::VkSamplerYcbcrRange;

alias ChromaLocation = vulkan::vk::VkChromaLocation;

alias SamplerReductionMode = vulkan::vk::VkSamplerReductionMode;

constdef BlendOverlapEXT : int
{
	UNCORRELATED = 0,
	DISJOINT     = 1,
	CONJOINT     = 2,
}

constdef FullScreenExclusiveEXT : int
{
	DEFAULT                = 0,
	ALLOWED                = 1,
	DISALLOWED             = 2,
	APPLICATION_CONTROLLED = 3,
}

alias ShaderFloatControlsIndependence = vulkan::vk::VkShaderFloatControlsIndependence;

constdef FragmentShadingRateCombinerOpKHR : int
{
	KEEP    = 0,
	REPLACE = 1,
	MIN     = 2,
	MAX     = 3,
	MUL     = 4,
}

constdef OpticalFlowPerformanceLevelNV : int
{
	UNKNOWN = 0,
	SLOW    = 1,
	MEDIUM  = 2,
	FAST    = 3,
}

constdef OpticalFlowSessionBindingPointNV : int
{
	UNKNOWN              = 0,
	INPUT                = 1,
	REFERENCE            = 2,
	HINT                 = 3,
	FLOW_VECTOR          = 4,
	BACKWARD_FLOW_VECTOR = 5,
	COST                 = 6,
	BACKWARD_COST        = 7,
	GLOBAL_FLOW          = 8,
}

constdef DeviceFaultAddressTypeEXT : int
{
	NONE                        = 0,
	READ_INVALID                = 1,
	WRITE_INVALID               = 2,
	EXECUTE_INVALID             = 3,
	INSTRUCTION_POINTER_UNKNOWN = 4,
	INSTRUCTION_POINTER_INVALID = 5,
	INSTRUCTION_POINTER_FAULT   = 6,
}

constdef LayerSettingTypeEXT : int
{
	BOOL32  = 0,
	INT32   = 1,
	INT64   = 2,
	UINT32  = 3,
	UINT64  = 4,
	FLOAT32 = 5,
	FLOAT64 = 6,
	STRING  = 7,
}

constdef LatencyMarkerNV : int
{
	SIMULATION_START               = 0,
	SIMULATION_END                 = 1,
	RENDERSUBMIT_START             = 2,
	RENDERSUBMIT_END               = 3,
	PRESENT_START                  = 4,
	PRESENT_END                    = 5,
	INPUT_SAMPLE                   = 6,
	TRIGGER_FLASH                  = 7,
	OUT_OF_BAND_RENDERSUBMIT_START = 8,
	OUT_OF_BAND_RENDERSUBMIT_END   = 9,
	OUT_OF_BAND_PRESENT_START      = 10,
	OUT_OF_BAND_PRESENT_END        = 11,
}

constdef OutOfBandQueueTypeNV : int
{
	RENDER  = 0,
	PRESENT = 1,
}

alias VendorId = vulkan::vk::VkVendorId;

alias DriverId = vulkan::vk::VkDriverId;

constdef ShadingRatePaletteEntryNV : int
{
	NO_INVOCATIONS                    = 0,
	ENTRY_16_INVOCATIONS_PER_PIXEL    = 1,
	ENTRY_8_INVOCATIONS_PER_PIXEL     = 2,
	ENTRY_4_INVOCATIONS_PER_PIXEL     = 3,
	ENTRY_2_INVOCATIONS_PER_PIXEL     = 4,
	ENTRY_1_INVOCATION_PER_PIXEL      = 5,
	ENTRY_1_INVOCATION_PER_2X1_PIXELS = 6,
	ENTRY_1_INVOCATION_PER_1X2_PIXELS = 7,
	ENTRY_1_INVOCATION_PER_2X2_PIXELS = 8,
	ENTRY_1_INVOCATION_PER_4X2_PIXELS = 9,
	ENTRY_1_INVOCATION_PER_2X4_PIXELS = 10,
	ENTRY_1_INVOCATION_PER_4X4_PIXELS = 11,
}

constdef CoarseSampleOrderTypeNV : int
{
	DEFAULT      = 0,
	CUSTOM       = 1,
	PIXEL_MAJOR  = 2,
	SAMPLE_MAJOR = 3,
}

constdef PipelineExecutableStatisticFormatKHR : int
{
	BOOL32  = 0,
	INT64   = 1,
	UINT64  = 2,
	FLOAT64 = 3,
}

constdef DefaultVertexAttributeValueKHR : int
{
	ZERO_ZERO_ZERO_ZERO = 0,
	ZERO_ZERO_ZERO_ONE  = 1,
}

constdef AccelerationStructureMotionInstanceTypeNV : int
{
	STATIC        = 0,
	MATRIX_MOTION = 1,
	SRT_MOTION    = 2,
}

// Bitmasks. XFlagBits is an alias of XFlags; bits are module constants.
alias FramebufferCreateFlags = vulkan::vk::VkFramebufferCreateFlags;
alias FramebufferCreateFlagBits = FramebufferCreateFlags;
const FramebufferCreateFlags FRAMEBUFFER_CREATE_IMAGELESS_BIT     = 0x00000001;
const FramebufferCreateFlags FRAMEBUFFER_CREATE_IMAGELESS_BIT_KHR = FRAMEBUFFER_CREATE_IMAGELESS_BIT;

alias QueryPoolCreateFlags = vulkan::vk::VkQueryPoolCreateFlags;
alias QueryPoolCreateFlagBits = QueryPoolCreateFlags;
const QueryPoolCreateFlags QUERY_POOL_CREATE_RESET_BIT_KHR = 0x00000001;

alias RenderPassCreateFlags = vulkan::vk::VkRenderPassCreateFlags;
alias RenderPassCreateFlagBits = RenderPassCreateFlags;
const RenderPassCreateFlags RENDER_PASS_CREATE_TRANSFORM_BIT_QCOM                   = 0x00000002;
const RenderPassCreateFlags RENDER_PASS_CREATE_PER_LAYER_FRAGMENT_DENSITY_BIT_VALVE = 0x00000004;

alias SamplerCreateFlags = vulkan::vk::VkSamplerCreateFlags;
alias SamplerCreateFlagBits = SamplerCreateFlags;
const SamplerCreateFlags SAMPLER_CREATE_SUBSAMPLED_BIT_EXT                       = 0x00000001;
const SamplerCreateFlags SAMPLER_CREATE_SUBSAMPLED_COARSE_RECONSTRUCTION_BIT_EXT = 0x00000002;
const SamplerCreateFlags SAMPLER_CREATE_DESCRIPTOR_BUFFER_CAPTURE_REPLAY_BIT_EXT = 0x00000008;
const SamplerCreateFlags SAMPLER_CREATE_NON_SEAMLESS_CUBE_MAP_BIT_EXT            = 0x00000004;
const SamplerCreateFlags SAMPLER_CREATE_IMAGE_PROCESSING_BIT_QCOM                = 0x00000010;

alias PipelineLayoutCreateFlags = vulkan::vk::VkPipelineLayoutCreateFlags;
alias PipelineLayoutCreateFlagBits = PipelineLayoutCreateFlags;
const PipelineLayoutCreateFlags PIPELINE_LAYOUT_CREATE_INDEPENDENT_SETS_BIT_EXT = 0x00000002;

alias PipelineCacheCreateFlags = vulkan::vk::VkPipelineCacheCreateFlags;
alias PipelineCacheCreateFlagBits = PipelineCacheCreateFlags;
const PipelineCacheCreateFlags PIPELINE_CACHE_CREATE_EXTERNALLY_SYNCHRONIZED_BIT           = 0x00000001;
const PipelineCacheCreateFlags PIPELINE_CACHE_CREATE_EXTERNALLY_SYNCHRONIZED_BIT_EXT       = PIPELINE_CACHE_CREATE_EXTERNALLY_SYNCHRONIZED_BIT;
const PipelineCacheCreateFlags PIPELINE_CACHE_CREATE_INTERNALLY_SYNCHRONIZED_MERGE_BIT_KHR = 0x00000008;

alias PipelineDepthStencilStateCreateFlags = vulkan::vk::VkPipelineDepthStencilStateCreateFlags;
alias PipelineDepthStencilStateCreateFlagBits = PipelineDepthStencilStateCreateFlags;
const PipelineDepthStencilStateCreateFlags PIPELINE_DEPTH_STENCIL_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_DEPTH_ACCESS_BIT_ARM   = PIPELINE_DEPTH_STENCIL_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_DEPTH_ACCESS_BIT_EXT;
const PipelineDepthStencilStateCreateFlags PIPELINE_DEPTH_STENCIL_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_STENCIL_ACCESS_BIT_ARM = PIPELINE_DEPTH_STENCIL_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_STENCIL_ACCESS_BIT_EXT;
const PipelineDepthStencilStateCreateFlags PIPELINE_DEPTH_STENCIL_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_DEPTH_ACCESS_BIT_EXT   = 0x00000001;
const PipelineDepthStencilStateCreateFlags PIPELINE_DEPTH_STENCIL_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_STENCIL_ACCESS_BIT_EXT = 0x00000002;

alias PipelineDynamicStateCreateFlags = vulkan::vk::VkPipelineDynamicStateCreateFlags;

alias PipelineColorBlendStateCreateFlags = vulkan::vk::VkPipelineColorBlendStateCreateFlags;
alias PipelineColorBlendStateCreateFlagBits = PipelineColorBlendStateCreateFlags;
const PipelineColorBlendStateCreateFlags PIPELINE_COLOR_BLEND_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_ACCESS_BIT_ARM = PIPELINE_COLOR_BLEND_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_ACCESS_BIT_EXT;
const PipelineColorBlendStateCreateFlags PIPELINE_COLOR_BLEND_STATE_CREATE_RASTERIZATION_ORDER_ATTACHMENT_ACCESS_BIT_EXT = 0x00000001;

alias PipelineMultisampleStateCreateFlags = vulkan::vk::VkPipelineMultisampleStateCreateFlags;

alias PipelineRasterizationStateCreateFlags = vulkan::vk::VkPipelineRasterizationStateCreateFlags;

alias PipelineViewportStateCreateFlags = vulkan::vk::VkPipelineViewportStateCreateFlags;

alias PipelineTessellationStateCreateFlags = vulkan::vk::VkPipelineTessellationStateCreateFlags;

alias PipelineInputAssemblyStateCreateFlags = vulkan::vk::VkPipelineInputAssemblyStateCreateFlags;

alias PipelineVertexInputStateCreateFlags = vulkan::vk::VkPipelineVertexInputStateCreateFlags;

alias PipelineShaderStageCreateFlags = vulkan::vk::VkPipelineShaderStageCreateFlags;
alias PipelineShaderStageCreateFlagBits = PipelineShaderStageCreateFlags;
const PipelineShaderStageCreateFlags PIPELINE_SHADER_STAGE_CREATE_ALLOW_VARYING_SUBGROUP_SIZE_BIT     = 0x00000001;
const PipelineShaderStageCreateFlags PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT          = 0x00000002;
const PipelineShaderStageCreateFlags PIPELINE_SHADER_STAGE_CREATE_ALLOW_VARYING_SUBGROUP_SIZE_BIT_EXT = PIPELINE_SHADER_STAGE_CREATE_ALLOW_VARYING_SUBGROUP_SIZE_BIT;
const PipelineShaderStageCreateFlags PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT_EXT      = PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT;

alias DescriptorSetLayoutCreateFlags = vulkan::vk::VkDescriptorSetLayoutCreateFlags;
alias DescriptorSetLayoutCreateFlagBits = DescriptorSetLayoutCreateFlags;
const DescriptorSetLayoutCreateFlags DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT          = 0x00000002;
const DescriptorSetLayoutCreateFlags DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT                 = 0x00000001;
const DescriptorSetLayoutCreateFlags DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT_KHR             = DESCRIPTOR_SET_LAYOUT_CREATE_PUSH_DESCRIPTOR_BIT;
const DescriptorSetLayoutCreateFlags DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT_EXT      = DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT;
const DescriptorSetLayoutCreateFlags DESCRIPTOR_SET_LAYOUT_CREATE_DESCRIPTOR_BUFFER_BIT_EXT           = 0x00000010;
const DescriptorSetLayoutCreateFlags DESCRIPTOR_SET_LAYOUT_CREATE_EMBEDDED_IMMUTABLE_SAMPLERS_BIT_EXT = 0x00000020;
const DescriptorSetLayoutCreateFlags DESCRIPTOR_SET_LAYOUT_CREATE_HOST_ONLY_POOL_BIT_VALVE            = DESCRIPTOR_SET_LAYOUT_CREATE_HOST_ONLY_POOL_BIT_EXT;
const DescriptorSetLayoutCreateFlags DESCRIPTOR_SET_LAYOUT_CREATE_INDIRECT_BINDABLE_BIT_NV            = 0x00000080;
const DescriptorSetLayoutCreateFlags DESCRIPTOR_SET_LAYOUT_CREATE_HOST_ONLY_POOL_BIT_EXT              = 0x00000004;
const DescriptorSetLayoutCreateFlags DESCRIPTOR_SET_LAYOUT_CREATE_PER_STAGE_BIT_NV                    = 0x00000040;

alias BufferViewCreateFlags = vulkan::vk::VkBufferViewCreateFlags;

alias InstanceCreateFlags = vulkan::vk::VkInstanceCreateFlags;
alias InstanceCreateFlagBits = InstanceCreateFlags;
const InstanceCreateFlags INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR = 0x00000001;

alias DeviceCreateFlags = vulkan::vk::VkDeviceCreateFlags;

alias DeviceQueueCreateFlags = vulkan::vk::VkDeviceQueueCreateFlags;
alias DeviceQueueCreateFlagBits = DeviceQueueCreateFlags;
const DeviceQueueCreateFlags DEVICE_QUEUE_CREATE_PROTECTED_BIT                   = 0x00000001;
const DeviceQueueCreateFlags DEVICE_QUEUE_CREATE_INTERNALLY_SYNCHRONIZED_BIT_KHR = 0x00000004;

alias QueueFlags = vulkan::vk::VkQueueFlags;
alias QueueFlagBits = QueueFlags;
const QueueFlags QUEUE_GRAPHICS_BIT        = 0x00000001;
const QueueFlags QUEUE_COMPUTE_BIT         = 0x00000002;
const QueueFlags QUEUE_TRANSFER_BIT        = 0x00000004;
const QueueFlags QUEUE_SPARSE_BINDING_BIT  = 0x00000008;
const QueueFlags QUEUE_PROTECTED_BIT       = 0x00000010;
const QueueFlags QUEUE_OPTICAL_FLOW_BIT_NV = 0x00000100;
const QueueFlags QUEUE_DATA_GRAPH_BIT_ARM  = 0x00000400;

alias MemoryPropertyFlags = vulkan::vk::VkMemoryPropertyFlags;
alias MemoryPropertyFlagBits = MemoryPropertyFlags;
const MemoryPropertyFlags MEMORY_PROPERTY_DEVICE_LOCAL_BIT        = 0x00000001;
const MemoryPropertyFlags MEMORY_PROPERTY_HOST_VISIBLE_BIT        = 0x00000002;
const MemoryPropertyFlags MEMORY_PROPERTY_HOST_COHERENT_BIT       = 0x00000004;
const MemoryPropertyFlags MEMORY_PROPERTY_HOST_CACHED_BIT         = 0x00000008;
const MemoryPropertyFlags MEMORY_PROPERTY_LAZILY_ALLOCATED_BIT    = 0x00000010;
const MemoryPropertyFlags MEMORY_PROPERTY_PROTECTED_BIT           = 0x00000020;
const MemoryPropertyFlags MEMORY_PROPERTY_DEVICE_COHERENT_BIT_AMD = 0x00000040;
const MemoryPropertyFlags MEMORY_PROPERTY_DEVICE_UNCACHED_BIT_AMD = 0x00000080;
const MemoryPropertyFlags MEMORY_PROPERTY_RDMA_CAPABLE_BIT_NV     = 0x00000100;

alias MemoryHeapFlags = vulkan::vk::VkMemoryHeapFlags;
alias MemoryHeapFlagBits = MemoryHeapFlags;
const MemoryHeapFlags MEMORY_HEAP_DEVICE_LOCAL_BIT       = 0x00000001;
const MemoryHeapFlags MEMORY_HEAP_MULTI_INSTANCE_BIT     = 0x00000002;
const MemoryHeapFlags MEMORY_HEAP_MULTI_INSTANCE_BIT_KHR = MEMORY_HEAP_MULTI_INSTANCE_BIT;
const MemoryHeapFlags MEMORY_HEAP_TILE_MEMORY_BIT_QCOM   = 0x00000008;

alias AccessFlags = vulkan::vk::VkAccessFlags;
alias AccessFlagBits = AccessFlags;
const AccessFlags ACCESS_INDIRECT_COMMAND_READ_BIT                     = 0x00000001;
const AccessFlags ACCESS_INDEX_READ_BIT                                = 0x00000002;
const AccessFlags ACCESS_VERTEX_ATTRIBUTE_READ_BIT                     = 0x00000004;
const AccessFlags ACCESS_UNIFORM_READ_BIT                              = 0x00000008;
const AccessFlags ACCESS_INPUT_ATTACHMENT_READ_BIT                     = 0x00000010;
const AccessFlags ACCESS_SHADER_READ_BIT                               = 0x00000020;
const AccessFlags ACCESS_SHADER_WRITE_BIT                              = 0x00000040;
const AccessFlags ACCESS_COLOR_ATTACHMENT_READ_BIT                     = 0x00000080;
const AccessFlags ACCESS_COLOR_ATTACHMENT_WRITE_BIT                    = 0x00000100;
const AccessFlags ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT             = 0x00000200;
const AccessFlags ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT            = 0x00000400;
const AccessFlags ACCESS_TRANSFER_READ_BIT                             = 0x00000800;
const AccessFlags ACCESS_TRANSFER_WRITE_BIT                            = 0x00001000;
const AccessFlags ACCESS_HOST_READ_BIT                                 = 0x00002000;
const AccessFlags ACCESS_HOST_WRITE_BIT                                = 0x00004000;
const AccessFlags ACCESS_MEMORY_READ_BIT                               = 0x00008000;
const AccessFlags ACCESS_MEMORY_WRITE_BIT                              = 0x00010000;
const AccessFlags ACCESS_NONE                                          = 0x00000000;
const AccessFlags ACCESS_TRANSFORM_FEEDBACK_WRITE_BIT_EXT              = 0x02000000;
const AccessFlags ACCESS_TRANSFORM_FEEDBACK_COUNTER_READ_BIT_EXT       = 0x04000000;
const AccessFlags ACCESS_TRANSFORM_FEEDBACK_COUNTER_WRITE_BIT_EXT      = 0x08000000;
const AccessFlags ACCESS_CONDITIONAL_RENDERING_READ_BIT_EXT            = 0x00100000;
const AccessFlags ACCESS_COLOR_ATTACHMENT_READ_NONCOHERENT_BIT_EXT     = 0x00080000;
const AccessFlags ACCESS_ACCELERATION_STRUCTURE_READ_BIT_KHR           = 0x00200000;
const AccessFlags ACCESS_ACCELERATION_STRUCTURE_WRITE_BIT_KHR          = 0x00400000;
const AccessFlags ACCESS_SHADING_RATE_IMAGE_READ_BIT_NV                = ACCESS_FRAGMENT_SHADING_RATE_ATTACHMENT_READ_BIT_KHR;
const AccessFlags ACCESS_ACCELERATION_STRUCTURE_READ_BIT_NV            = ACCESS_ACCELERATION_STRUCTURE_READ_BIT_KHR;
const AccessFlags ACCESS_ACCELERATION_STRUCTURE_WRITE_BIT_NV           = ACCESS_ACCELERATION_STRUCTURE_WRITE_BIT_KHR;
const AccessFlags ACCESS_FRAGMENT_DENSITY_MAP_READ_BIT_EXT             = 0x01000000;
const AccessFlags ACCESS_FRAGMENT_SHADING_RATE_ATTACHMENT_READ_BIT_KHR = 0x00800000;
const AccessFlags ACCESS_COMMAND_PREPROCESS_READ_BIT_NV                = ACCESS_COMMAND_PREPROCESS_READ_BIT_EXT;
const AccessFlags ACCESS_COMMAND_PREPROCESS_WRITE_BIT_NV               = ACCESS_COMMAND_PREPROCESS_WRITE_BIT_EXT;
const AccessFlags ACCESS_NONE_KHR                                      = ACCESS_NONE;
const AccessFlags ACCESS_COMMAND_PREPROCESS_READ_BIT_EXT               = 0x00020000;
const AccessFlags ACCESS_COMMAND_PREPROCESS_WRITE_BIT_EXT              = 0x00040000;

alias BufferUsageFlags = vulkan::vk::VkBufferUsageFlags;
alias BufferUsageFlagBits = BufferUsageFlags;
const BufferUsageFlags BUFFER_USAGE_TRANSFER_SRC_BIT                                     = 0x00000001;
const BufferUsageFlags BUFFER_USAGE_TRANSFER_DST_BIT                                     = 0x00000002;
const BufferUsageFlags BUFFER_USAGE_UNIFORM_TEXEL_BUFFER_BIT                             = 0x00000004;
const BufferUsageFlags BUFFER_USAGE_STORAGE_TEXEL_BUFFER_BIT                             = 0x00000008;
const BufferUsageFlags BUFFER_USAGE_UNIFORM_BUFFER_BIT                                   = 0x00000010;
const BufferUsageFlags BUFFER_USAGE_STORAGE_BUFFER_BIT                                   = 0x00000020;
const BufferUsageFlags BUFFER_USAGE_INDEX_BUFFER_BIT                                     = 0x00000040;
const BufferUsageFlags BUFFER_USAGE_VERTEX_BUFFER_BIT                                    = 0x00000080;
const BufferUsageFlags BUFFER_USAGE_INDIRECT_BUFFER_BIT                                  = 0x00000100;
const BufferUsageFlags BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT                            = 0x00020000;
const BufferUsageFlags BUFFER_USAGE_TRANSFORM_FEEDBACK_BUFFER_BIT_EXT                    = 0x00000800;
const BufferUsageFlags BUFFER_USAGE_TRANSFORM_FEEDBACK_COUNTER_BUFFER_BIT_EXT            = 0x00001000;
const BufferUsageFlags BUFFER_USAGE_CONDITIONAL_RENDERING_BIT_EXT                        = 0x00000200;
const BufferUsageFlags BUFFER_USAGE_DESCRIPTOR_HEAP_BIT_EXT                              = 0x10000000;
const BufferUsageFlags BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR = 0x00080000;
const BufferUsageFlags BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR               = 0x00100000;
const BufferUsageFlags BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR                         = 0x00000400;
const BufferUsageFlags BUFFER_USAGE_RAY_TRACING_BIT_NV                                   = BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR;
const BufferUsageFlags BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT_EXT                        = BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT;
const BufferUsageFlags BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT_KHR                        = BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT;
const BufferUsageFlags BUFFER_USAGE_SAMPLER_DESCRIPTOR_BUFFER_BIT_EXT                    = 0x00200000;
const BufferUsageFlags BUFFER_USAGE_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT                   = 0x00400000;
const BufferUsageFlags BUFFER_USAGE_PUSH_DESCRIPTORS_DESCRIPTOR_BUFFER_BIT_EXT           = 0x04000000;
const BufferUsageFlags BUFFER_USAGE_MICROMAP_BUILD_INPUT_READ_ONLY_BIT_EXT               = 0x00800000;
const BufferUsageFlags BUFFER_USAGE_MICROMAP_STORAGE_BIT_EXT                             = 0x01000000;
const BufferUsageFlags BUFFER_USAGE_TILE_MEMORY_BIT_QCOM                                 = 0x08000000;

alias BufferCreateFlags = vulkan::vk::VkBufferCreateFlags;
alias BufferCreateFlagBits = BufferCreateFlags;
const BufferCreateFlags BUFFER_CREATE_SPARSE_BINDING_BIT                       = 0x00000001;
const BufferCreateFlags BUFFER_CREATE_SPARSE_RESIDENCY_BIT                     = 0x00000002;
const BufferCreateFlags BUFFER_CREATE_SPARSE_ALIASED_BIT                       = 0x00000004;
const BufferCreateFlags BUFFER_CREATE_PROTECTED_BIT                            = 0x00000008;
const BufferCreateFlags BUFFER_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT        = 0x00000010;
const BufferCreateFlags BUFFER_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT_EXT    = BUFFER_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT;
const BufferCreateFlags BUFFER_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT_KHR    = BUFFER_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT;
const BufferCreateFlags BUFFER_CREATE_DESCRIPTOR_BUFFER_CAPTURE_REPLAY_BIT_EXT = 0x00000020;

alias ShaderStageFlags = vulkan::vk::VkShaderStageFlags;
alias ShaderStageFlagBits = vulkan::vk::VkShaderStageFlagBits;
const ShaderStageFlags SHADER_STAGE_VERTEX_BIT                  = 0x00000001;
const ShaderStageFlags SHADER_STAGE_TESSELLATION_CONTROL_BIT    = 0x00000002;
const ShaderStageFlags SHADER_STAGE_TESSELLATION_EVALUATION_BIT = 0x00000004;
const ShaderStageFlags SHADER_STAGE_GEOMETRY_BIT                = 0x00000008;
const ShaderStageFlags SHADER_STAGE_FRAGMENT_BIT                = 0x00000010;
const ShaderStageFlags SHADER_STAGE_COMPUTE_BIT                 = 0x00000020;
const ShaderStageFlags SHADER_STAGE_ALL_GRAPHICS                = 0x0000001F;
const ShaderStageFlags SHADER_STAGE_ALL                         = 0x7FFFFFFF;
const ShaderStageFlags SHADER_STAGE_RAYGEN_BIT_KHR              = 0x00000100;
const ShaderStageFlags SHADER_STAGE_ANY_HIT_BIT_KHR             = 0x00000200;
const ShaderStageFlags SHADER_STAGE_CLOSEST_HIT_BIT_KHR         = 0x00000400;
const ShaderStageFlags SHADER_STAGE_MISS_BIT_KHR                = 0x00000800;
const ShaderStageFlags SHADER_STAGE_INTERSECTION_BIT_KHR        = 0x00001000;
const ShaderStageFlags SHADER_STAGE_CALLABLE_BIT_KHR            = 0x00002000;
const ShaderStageFlags SHADER_STAGE_RAYGEN_BIT_NV               = SHADER_STAGE_RAYGEN_BIT_KHR;
const ShaderStageFlags SHADER_STAGE_ANY_HIT_BIT_NV              = SHADER_STAGE_ANY_HIT_BIT_KHR;
const ShaderStageFlags SHADER_STAGE_CLOSEST_HIT_BIT_NV          = SHADER_STAGE_CLOSEST_HIT_BIT_KHR;
const ShaderStageFlags SHADER_STAGE_MISS_BIT_NV                 = SHADER_STAGE_MISS_BIT_KHR;
const ShaderStageFlags SHADER_STAGE_INTERSECTION_BIT_NV         = SHADER_STAGE_INTERSECTION_BIT_KHR;
const ShaderStageFlags SHADER_STAGE_CALLABLE_BIT_NV             = SHADER_STAGE_CALLABLE_BIT_KHR;
const ShaderStageFlags SHADER_STAGE_TASK_BIT_NV                 = SHADER_STAGE_TASK_BIT_EXT;
const ShaderStageFlags SHADER_STAGE_MESH_BIT_NV                 = SHADER_STAGE_MESH_BIT_EXT;
const ShaderStageFlags SHADER_STAGE_TASK_BIT_EXT                = 0x00000040;
const ShaderStageFlags SHADER_STAGE_MESH_BIT_EXT                = 0x00000080;
const ShaderStageFlags SHADER_STAGE_SUBPASS_SHADING_BIT_HUAWEI  = 0x00004000;
const ShaderStageFlags SHADER_STAGE_CLUSTER_CULLING_BIT_HUAWEI  = 0x00080000;

alias ImageUsageFlags = vulkan::vk::VkImageUsageFlags;
alias ImageUsageFlagBits = ImageUsageFlags;
const ImageUsageFlags IMAGE_USAGE_TRANSFER_SRC_BIT                         = 0x00000001;
const ImageUsageFlags IMAGE_USAGE_TRANSFER_DST_BIT                         = 0x00000002;
const ImageUsageFlags IMAGE_USAGE_SAMPLED_BIT                              = 0x00000004;
const ImageUsageFlags IMAGE_USAGE_STORAGE_BIT                              = 0x00000008;
const ImageUsageFlags IMAGE_USAGE_COLOR_ATTACHMENT_BIT                     = 0x00000010;
const ImageUsageFlags IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT             = 0x00000020;
const ImageUsageFlags IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT                 = 0x00000040;
const ImageUsageFlags IMAGE_USAGE_INPUT_ATTACHMENT_BIT                     = 0x00000080;
const ImageUsageFlags IMAGE_USAGE_HOST_TRANSFER_BIT                        = 0x00400000;
const ImageUsageFlags IMAGE_USAGE_SHADING_RATE_IMAGE_BIT_NV                = IMAGE_USAGE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR;
const ImageUsageFlags IMAGE_USAGE_FRAGMENT_DENSITY_MAP_BIT_EXT             = 0x00000200;
const ImageUsageFlags IMAGE_USAGE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR = 0x00000100;
const ImageUsageFlags IMAGE_USAGE_HOST_TRANSFER_BIT_EXT                    = IMAGE_USAGE_HOST_TRANSFER_BIT;
const ImageUsageFlags IMAGE_USAGE_ATTACHMENT_FEEDBACK_LOOP_BIT_EXT         = 0x00080000;
const ImageUsageFlags IMAGE_USAGE_INVOCATION_MASK_BIT_HUAWEI               = 0x00040000;
const ImageUsageFlags IMAGE_USAGE_SAMPLE_WEIGHT_BIT_QCOM                   = 0x00100000;
const ImageUsageFlags IMAGE_USAGE_SAMPLE_BLOCK_MATCH_BIT_QCOM              = 0x00200000;
const ImageUsageFlags IMAGE_USAGE_TENSOR_ALIASING_BIT_ARM                  = 0x00800000;
const ImageUsageFlags IMAGE_USAGE_TILE_MEMORY_BIT_QCOM                     = 0x08000000;

alias ImageCreateFlags = vulkan::vk::VkImageCreateFlags;
alias ImageCreateFlagBits = ImageCreateFlags;
const ImageCreateFlags IMAGE_CREATE_SPARSE_BINDING_BIT                            = 0x00000001;
const ImageCreateFlags IMAGE_CREATE_SPARSE_RESIDENCY_BIT                          = 0x00000002;
const ImageCreateFlags IMAGE_CREATE_SPARSE_ALIASED_BIT                            = 0x00000004;
const ImageCreateFlags IMAGE_CREATE_MUTABLE_FORMAT_BIT                            = 0x00000008;
const ImageCreateFlags IMAGE_CREATE_CUBE_COMPATIBLE_BIT                           = 0x00000010;
const ImageCreateFlags IMAGE_CREATE_ALIAS_BIT                                     = 0x00000400;
const ImageCreateFlags IMAGE_CREATE_SPLIT_INSTANCE_BIND_REGIONS_BIT               = 0x00000040;
const ImageCreateFlags IMAGE_CREATE_2D_ARRAY_COMPATIBLE_BIT                       = 0x00000020;
const ImageCreateFlags IMAGE_CREATE_BLOCK_TEXEL_VIEW_COMPATIBLE_BIT               = 0x00000080;
const ImageCreateFlags IMAGE_CREATE_EXTENDED_USAGE_BIT                            = 0x00000100;
const ImageCreateFlags IMAGE_CREATE_PROTECTED_BIT                                 = 0x00000800;
const ImageCreateFlags IMAGE_CREATE_DISJOINT_BIT                                  = 0x00000200;
const ImageCreateFlags IMAGE_CREATE_CORNER_SAMPLED_BIT_NV                         = 0x00002000;
const ImageCreateFlags IMAGE_CREATE_SPLIT_INSTANCE_BIND_REGIONS_BIT_KHR           = IMAGE_CREATE_SPLIT_INSTANCE_BIND_REGIONS_BIT;
const ImageCreateFlags IMAGE_CREATE_2D_ARRAY_COMPATIBLE_BIT_KHR                   = IMAGE_CREATE_2D_ARRAY_COMPATIBLE_BIT;
const ImageCreateFlags IMAGE_CREATE_BLOCK_TEXEL_VIEW_COMPATIBLE_BIT_KHR           = IMAGE_CREATE_BLOCK_TEXEL_VIEW_COMPATIBLE_BIT;
const ImageCreateFlags IMAGE_CREATE_EXTENDED_USAGE_BIT_KHR                        = IMAGE_CREATE_EXTENDED_USAGE_BIT;
const ImageCreateFlags IMAGE_CREATE_DESCRIPTOR_HEAP_CAPTURE_REPLAY_BIT_EXT        = 0x00010000;
const ImageCreateFlags IMAGE_CREATE_SAMPLE_LOCATIONS_COMPATIBLE_DEPTH_BIT_EXT     = 0x00001000;
const ImageCreateFlags IMAGE_CREATE_DISJOINT_BIT_KHR                              = IMAGE_CREATE_DISJOINT_BIT;
const ImageCreateFlags IMAGE_CREATE_ALIAS_BIT_KHR                                 = IMAGE_CREATE_ALIAS_BIT;
const ImageCreateFlags IMAGE_CREATE_SUBSAMPLED_BIT_EXT                            = 0x00004000;
const ImageCreateFlags IMAGE_CREATE_DESCRIPTOR_BUFFER_CAPTURE_REPLAY_BIT_EXT      = IMAGE_CREATE_DESCRIPTOR_HEAP_CAPTURE_REPLAY_BIT_EXT;
const ImageCreateFlags IMAGE_CREATE_MULTISAMPLED_RENDER_TO_SINGLE_SAMPLED_BIT_EXT = 0x00040000;
const ImageCreateFlags IMAGE_CREATE_2D_VIEW_COMPATIBLE_BIT_EXT                    = 0x00020000;
const ImageCreateFlags IMAGE_CREATE_FRAGMENT_DENSITY_MAP_OFFSET_BIT_QCOM          = IMAGE_CREATE_FRAGMENT_DENSITY_MAP_OFFSET_BIT_EXT;
const ImageCreateFlags IMAGE_CREATE_FRAGMENT_DENSITY_MAP_OFFSET_BIT_EXT           = 0x00008000;

alias ImageViewCreateFlags = vulkan::vk::VkImageViewCreateFlags;
alias ImageViewCreateFlagBits = ImageViewCreateFlags;
const ImageViewCreateFlags IMAGE_VIEW_CREATE_FRAGMENT_DENSITY_MAP_DYNAMIC_BIT_EXT     = 0x00000001;
const ImageViewCreateFlags IMAGE_VIEW_CREATE_DESCRIPTOR_BUFFER_CAPTURE_REPLAY_BIT_EXT = 0x00000004;
const ImageViewCreateFlags IMAGE_VIEW_CREATE_FRAGMENT_DENSITY_MAP_DEFERRED_BIT_EXT    = 0x00000002;

alias PipelineCreateFlags = vulkan::vk::VkPipelineCreateFlags;
alias PipelineCreateFlagBits = PipelineCreateFlags;
const PipelineCreateFlags PIPELINE_CREATE_DISABLE_OPTIMIZATION_BIT                                     = 0x00000001;
const PipelineCreateFlags PIPELINE_CREATE_ALLOW_DERIVATIVES_BIT                                        = 0x00000002;
const PipelineCreateFlags PIPELINE_CREATE_DERIVATIVE_BIT                                               = 0x00000004;
const PipelineCreateFlags PIPELINE_CREATE_DISPATCH_BASE_BIT                                            = 0x00000010;
const PipelineCreateFlags PIPELINE_CREATE_DISPATCH_BASE                                                = PIPELINE_CREATE_DISPATCH_BASE_BIT;
const PipelineCreateFlags PIPELINE_CREATE_VIEW_INDEX_FROM_DEVICE_INDEX_BIT                             = 0x00000008;
const PipelineCreateFlags PIPELINE_CREATE_FAIL_ON_PIPELINE_COMPILE_REQUIRED_BIT                        = 0x00000100;
const PipelineCreateFlags PIPELINE_CREATE_EARLY_RETURN_ON_FAILURE_BIT                                  = 0x00000200;
const PipelineCreateFlags PIPELINE_CREATE_NO_PROTECTED_ACCESS_BIT                                      = 0x08000000;
const PipelineCreateFlags PIPELINE_CREATE_PROTECTED_ACCESS_ONLY_BIT                                    = 0x40000000;
const PipelineCreateFlags PIPELINE_CREATE_VIEW_INDEX_FROM_DEVICE_INDEX_BIT_KHR                         = PIPELINE_CREATE_VIEW_INDEX_FROM_DEVICE_INDEX_BIT;
const PipelineCreateFlags PIPELINE_CREATE_DISPATCH_BASE_BIT_KHR                                        = PIPELINE_CREATE_DISPATCH_BASE_BIT;
const PipelineCreateFlags PIPELINE_CREATE_DISPATCH_BASE_KHR                                            = PIPELINE_CREATE_DISPATCH_BASE_BIT;
const PipelineCreateFlags PIPELINE_CREATE_RAY_TRACING_NO_NULL_ANY_HIT_SHADERS_BIT_KHR                  = 0x00004000;
const PipelineCreateFlags PIPELINE_CREATE_RAY_TRACING_NO_NULL_CLOSEST_HIT_SHADERS_BIT_KHR              = 0x00008000;
const PipelineCreateFlags PIPELINE_CREATE_RAY_TRACING_NO_NULL_MISS_SHADERS_BIT_KHR                     = 0x00010000;
const PipelineCreateFlags PIPELINE_CREATE_RAY_TRACING_NO_NULL_INTERSECTION_SHADERS_BIT_KHR             = 0x00020000;
const PipelineCreateFlags PIPELINE_CREATE_RAY_TRACING_SKIP_TRIANGLES_BIT_KHR                           = 0x00001000;
const PipelineCreateFlags PIPELINE_CREATE_RAY_TRACING_SKIP_AABBS_BIT_KHR                               = 0x00002000;
const PipelineCreateFlags PIPELINE_CREATE_RAY_TRACING_SHADER_GROUP_HANDLE_CAPTURE_REPLAY_BIT_KHR       = 0x00080000;
const PipelineCreateFlags PIPELINE_CREATE_DEFER_COMPILE_BIT_NV                                         = 0x00000020;
const PipelineCreateFlags PIPELINE_CREATE_RENDERING_FRAGMENT_DENSITY_MAP_ATTACHMENT_BIT_EXT            = 0x00400000;
const PipelineCreateFlags PIPELINE_RASTERIZATION_STATE_CREATE_FRAGMENT_DENSITY_MAP_ATTACHMENT_BIT_EXT  = PIPELINE_CREATE_RENDERING_FRAGMENT_DENSITY_MAP_ATTACHMENT_BIT_EXT;
const PipelineCreateFlags PIPELINE_CREATE_RENDERING_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR           = 0x00200000;
const PipelineCreateFlags PIPELINE_RASTERIZATION_STATE_CREATE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR = PIPELINE_CREATE_RENDERING_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR;
const PipelineCreateFlags PIPELINE_CREATE_CAPTURE_STATISTICS_BIT_KHR                                   = 0x00000040;
const PipelineCreateFlags PIPELINE_CREATE_CAPTURE_INTERNAL_REPRESENTATIONS_BIT_KHR                     = 0x00000080;
const PipelineCreateFlags PIPELINE_CREATE_INDIRECT_BINDABLE_BIT_NV                                     = 0x00040000;
const PipelineCreateFlags PIPELINE_CREATE_LIBRARY_BIT_KHR                                              = 0x00000800;
const PipelineCreateFlags PIPELINE_CREATE_FAIL_ON_PIPELINE_COMPILE_REQUIRED_BIT_EXT                    = PIPELINE_CREATE_FAIL_ON_PIPELINE_COMPILE_REQUIRED_BIT;
const PipelineCreateFlags PIPELINE_CREATE_EARLY_RETURN_ON_FAILURE_BIT_EXT                              = PIPELINE_CREATE_EARLY_RETURN_ON_FAILURE_BIT;
const PipelineCreateFlags PIPELINE_CREATE_DESCRIPTOR_BUFFER_BIT_EXT                                    = 0x20000000;
const PipelineCreateFlags PIPELINE_CREATE_RETAIN_LINK_TIME_OPTIMIZATION_INFO_BIT_EXT                   = 0x00800000;
const PipelineCreateFlags PIPELINE_CREATE_LINK_TIME_OPTIMIZATION_BIT_EXT                               = 0x00000400;
const PipelineCreateFlags PIPELINE_CREATE_RAY_TRACING_ALLOW_MOTION_BIT_NV                              = 0x00100000;
const PipelineCreateFlags PIPELINE_CREATE_COLOR_ATTACHMENT_FEEDBACK_LOOP_BIT_EXT                       = 0x02000000;
const PipelineCreateFlags PIPELINE_CREATE_DEPTH_STENCIL_ATTACHMENT_FEEDBACK_LOOP_BIT_EXT               = 0x04000000;
const PipelineCreateFlags PIPELINE_CREATE_RAY_TRACING_OPACITY_MICROMAP_BIT_EXT                         = 0x01000000;
const PipelineCreateFlags PIPELINE_CREATE_NO_PROTECTED_ACCESS_BIT_EXT                                  = PIPELINE_CREATE_NO_PROTECTED_ACCESS_BIT;
const PipelineCreateFlags PIPELINE_CREATE_PROTECTED_ACCESS_ONLY_BIT_EXT                                = PIPELINE_CREATE_PROTECTED_ACCESS_ONLY_BIT;

alias ColorComponentFlags = vulkan::vk::VkColorComponentFlags;
alias ColorComponentFlagBits = ColorComponentFlags;
const ColorComponentFlags COLOR_COMPONENT_R_BIT = 0x00000001;
const ColorComponentFlags COLOR_COMPONENT_G_BIT = 0x00000002;
const ColorComponentFlags COLOR_COMPONENT_B_BIT = 0x00000004;
const ColorComponentFlags COLOR_COMPONENT_A_BIT = 0x00000008;

alias FenceCreateFlags = vulkan::vk::VkFenceCreateFlags;
alias FenceCreateFlagBits = FenceCreateFlags;
const FenceCreateFlags FENCE_CREATE_SIGNALED_BIT = 0x00000001;

alias SemaphoreCreateFlags = vulkan::vk::VkSemaphoreCreateFlags;

alias FormatFeatureFlags = vulkan::vk::VkFormatFeatureFlags;
alias FormatFeatureFlagBits = FormatFeatureFlags;
const FormatFeatureFlags FORMAT_FEATURE_SAMPLED_IMAGE_BIT                                                               = 0x00000001;
const FormatFeatureFlags FORMAT_FEATURE_STORAGE_IMAGE_BIT                                                               = 0x00000002;
const FormatFeatureFlags FORMAT_FEATURE_STORAGE_IMAGE_ATOMIC_BIT                                                        = 0x00000004;
const FormatFeatureFlags FORMAT_FEATURE_UNIFORM_TEXEL_BUFFER_BIT                                                        = 0x00000008;
const FormatFeatureFlags FORMAT_FEATURE_STORAGE_TEXEL_BUFFER_BIT                                                        = 0x00000010;
const FormatFeatureFlags FORMAT_FEATURE_STORAGE_TEXEL_BUFFER_ATOMIC_BIT                                                 = 0x00000020;
const FormatFeatureFlags FORMAT_FEATURE_VERTEX_BUFFER_BIT                                                               = 0x00000040;
const FormatFeatureFlags FORMAT_FEATURE_COLOR_ATTACHMENT_BIT                                                            = 0x00000080;
const FormatFeatureFlags FORMAT_FEATURE_COLOR_ATTACHMENT_BLEND_BIT                                                      = 0x00000100;
const FormatFeatureFlags FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT                                                    = 0x00000200;
const FormatFeatureFlags FORMAT_FEATURE_BLIT_SRC_BIT                                                                    = 0x00000400;
const FormatFeatureFlags FORMAT_FEATURE_BLIT_DST_BIT                                                                    = 0x00000800;
const FormatFeatureFlags FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_LINEAR_BIT                                                 = 0x00001000;
const FormatFeatureFlags FORMAT_FEATURE_TRANSFER_SRC_BIT                                                                = 0x00004000;
const FormatFeatureFlags FORMAT_FEATURE_TRANSFER_DST_BIT                                                                = 0x00008000;
const FormatFeatureFlags FORMAT_FEATURE_MIDPOINT_CHROMA_SAMPLES_BIT                                                     = 0x00020000;
const FormatFeatureFlags FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_LINEAR_FILTER_BIT                                = 0x00040000;
const FormatFeatureFlags FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_SEPARATE_RECONSTRUCTION_FILTER_BIT               = 0x00080000;
const FormatFeatureFlags FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_BIT               = 0x00100000;
const FormatFeatureFlags FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_FORCEABLE_BIT     = 0x00200000;
const FormatFeatureFlags FORMAT_FEATURE_DISJOINT_BIT                                                                    = 0x00400000;
const FormatFeatureFlags FORMAT_FEATURE_COSITED_CHROMA_SAMPLES_BIT                                                      = 0x00800000;
const FormatFeatureFlags FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_MINMAX_BIT                                                 = 0x00010000;
const FormatFeatureFlags FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_CUBIC_BIT_IMG                                              = FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_CUBIC_BIT_EXT;
const FormatFeatureFlags FORMAT_FEATURE_TRANSFER_SRC_BIT_KHR                                                            = FORMAT_FEATURE_TRANSFER_SRC_BIT;
const FormatFeatureFlags FORMAT_FEATURE_TRANSFER_DST_BIT_KHR                                                            = FORMAT_FEATURE_TRANSFER_DST_BIT;
const FormatFeatureFlags FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_MINMAX_BIT_EXT                                             = FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_MINMAX_BIT;
const FormatFeatureFlags FORMAT_FEATURE_ACCELERATION_STRUCTURE_VERTEX_BUFFER_BIT_KHR                                    = 0x20000000;
const FormatFeatureFlags FORMAT_FEATURE_MIDPOINT_CHROMA_SAMPLES_BIT_KHR                                                 = FORMAT_FEATURE_MIDPOINT_CHROMA_SAMPLES_BIT;
const FormatFeatureFlags FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_LINEAR_FILTER_BIT_KHR                            = FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_LINEAR_FILTER_BIT;
const FormatFeatureFlags FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_SEPARATE_RECONSTRUCTION_FILTER_BIT_KHR           = FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_SEPARATE_RECONSTRUCTION_FILTER_BIT;
const FormatFeatureFlags FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_BIT_KHR           = FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_BIT;
const FormatFeatureFlags FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_FORCEABLE_BIT_KHR = FORMAT_FEATURE_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_FORCEABLE_BIT;
const FormatFeatureFlags FORMAT_FEATURE_DISJOINT_BIT_KHR                                                                = FORMAT_FEATURE_DISJOINT_BIT;
const FormatFeatureFlags FORMAT_FEATURE_COSITED_CHROMA_SAMPLES_BIT_KHR                                                  = FORMAT_FEATURE_COSITED_CHROMA_SAMPLES_BIT;
const FormatFeatureFlags FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_CUBIC_BIT_EXT                                              = 0x00002000;
const FormatFeatureFlags FORMAT_FEATURE_FRAGMENT_DENSITY_MAP_BIT_EXT                                                    = 0x01000000;
const FormatFeatureFlags FORMAT_FEATURE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR                                        = 0x40000000;

alias QueryControlFlags = vulkan::vk::VkQueryControlFlags;
alias QueryControlFlagBits = QueryControlFlags;
const QueryControlFlags QUERY_CONTROL_PRECISE_BIT = 0x00000001;

alias QueryResultFlags = vulkan::vk::VkQueryResultFlags;
alias QueryResultFlagBits = QueryResultFlags;
const QueryResultFlags QUERY_RESULT_64_BIT                = 0x00000001;
const QueryResultFlags QUERY_RESULT_WAIT_BIT              = 0x00000002;
const QueryResultFlags QUERY_RESULT_WITH_AVAILABILITY_BIT = 0x00000004;
const QueryResultFlags QUERY_RESULT_PARTIAL_BIT           = 0x00000008;

alias ShaderModuleCreateFlags = vulkan::vk::VkShaderModuleCreateFlags;

alias EventCreateFlags = vulkan::vk::VkEventCreateFlags;
alias EventCreateFlagBits = EventCreateFlags;
const EventCreateFlags EVENT_CREATE_DEVICE_ONLY_BIT     = 0x00000001;
const EventCreateFlags EVENT_CREATE_DEVICE_ONLY_BIT_KHR = EVENT_CREATE_DEVICE_ONLY_BIT;

alias CommandPoolCreateFlags = vulkan::vk::VkCommandPoolCreateFlags;
alias CommandPoolCreateFlagBits = CommandPoolCreateFlags;
const CommandPoolCreateFlags COMMAND_POOL_CREATE_TRANSIENT_BIT            = 0x00000001;
const CommandPoolCreateFlags COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x00000002;
const CommandPoolCreateFlags COMMAND_POOL_CREATE_PROTECTED_BIT            = 0x00000004;

alias CommandPoolResetFlags = vulkan::vk::VkCommandPoolResetFlags;
alias CommandPoolResetFlagBits = CommandPoolResetFlags;
const CommandPoolResetFlags COMMAND_POOL_RESET_RELEASE_RESOURCES_BIT = 0x00000001;

alias CommandBufferResetFlags = vulkan::vk::VkCommandBufferResetFlags;
alias CommandBufferResetFlagBits = CommandBufferResetFlags;
const CommandBufferResetFlags COMMAND_BUFFER_RESET_RELEASE_RESOURCES_BIT = 0x00000001;

alias CommandBufferUsageFlags = vulkan::vk::VkCommandBufferUsageFlags;
alias CommandBufferUsageFlagBits = CommandBufferUsageFlags;
const CommandBufferUsageFlags COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT      = 0x00000001;
const CommandBufferUsageFlags COMMAND_BUFFER_USAGE_RENDER_PASS_CONTINUE_BIT = 0x00000002;
const CommandBufferUsageFlags COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT     = 0x00000004;

alias QueryPipelineStatisticFlags = vulkan::vk::VkQueryPipelineStatisticFlags;
alias QueryPipelineStatisticFlagBits = QueryPipelineStatisticFlags;
const QueryPipelineStatisticFlags QUERY_PIPELINE_STATISTIC_INPUT_ASSEMBLY_VERTICES_BIT                    = 0x00000001;
const QueryPipelineStatisticFlags QUERY_PIPELINE_STATISTIC_INPUT_ASSEMBLY_PRIMITIVES_BIT                  = 0x00000002;
const QueryPipelineStatisticFlags QUERY_PIPELINE_STATISTIC_VERTEX_SHADER_INVOCATIONS_BIT                  = 0x00000004;
const QueryPipelineStatisticFlags QUERY_PIPELINE_STATISTIC_GEOMETRY_SHADER_INVOCATIONS_BIT                = 0x00000008;
const QueryPipelineStatisticFlags QUERY_PIPELINE_STATISTIC_GEOMETRY_SHADER_PRIMITIVES_BIT                 = 0x00000010;
const QueryPipelineStatisticFlags QUERY_PIPELINE_STATISTIC_CLIPPING_INVOCATIONS_BIT                       = 0x00000020;
const QueryPipelineStatisticFlags QUERY_PIPELINE_STATISTIC_CLIPPING_PRIMITIVES_BIT                        = 0x00000040;
const QueryPipelineStatisticFlags QUERY_PIPELINE_STATISTIC_FRAGMENT_SHADER_INVOCATIONS_BIT                = 0x00000080;
const QueryPipelineStatisticFlags QUERY_PIPELINE_STATISTIC_TESSELLATION_CONTROL_SHADER_PATCHES_BIT        = 0x00000100;
const QueryPipelineStatisticFlags QUERY_PIPELINE_STATISTIC_TESSELLATION_EVALUATION_SHADER_INVOCATIONS_BIT = 0x00000200;
const QueryPipelineStatisticFlags QUERY_PIPELINE_STATISTIC_COMPUTE_SHADER_INVOCATIONS_BIT                 = 0x00000400;
const QueryPipelineStatisticFlags QUERY_PIPELINE_STATISTIC_TASK_SHADER_INVOCATIONS_BIT_EXT                = 0x00000800;
const QueryPipelineStatisticFlags QUERY_PIPELINE_STATISTIC_MESH_SHADER_INVOCATIONS_BIT_EXT                = 0x00001000;
const QueryPipelineStatisticFlags QUERY_PIPELINE_STATISTIC_CLUSTER_CULLING_SHADER_INVOCATIONS_BIT_HUAWEI  = 0x00002000;

alias MemoryMapFlags = vulkan::vk::VkMemoryMapFlags;
alias MemoryMapFlagBits = MemoryMapFlags;
const MemoryMapFlags MEMORY_MAP_PLACED_BIT_EXT = 0x00000001;

typedef MemoryUnmapFlags @constinit = uint;
alias MemoryUnmapFlagBits = MemoryUnmapFlags;
const MemoryUnmapFlags MEMORY_UNMAP_RESERVE_BIT_EXT = 0x00000001;

alias ImageAspectFlags = vulkan::vk::VkImageAspectFlags;
alias ImageAspectFlagBits = ImageAspectFlags;
const ImageAspectFlags IMAGE_ASPECT_COLOR_BIT              = 0x00000001;
const ImageAspectFlags IMAGE_ASPECT_DEPTH_BIT              = 0x00000002;
const ImageAspectFlags IMAGE_ASPECT_STENCIL_BIT            = 0x00000004;
const ImageAspectFlags IMAGE_ASPECT_METADATA_BIT           = 0x00000008;
const ImageAspectFlags IMAGE_ASPECT_PLANE_0_BIT            = 0x00000010;
const ImageAspectFlags IMAGE_ASPECT_PLANE_1_BIT            = 0x00000020;
const ImageAspectFlags IMAGE_ASPECT_PLANE_2_BIT            = 0x00000040;
const ImageAspectFlags IMAGE_ASPECT_NONE                   = 0x00000000;
const ImageAspectFlags IMAGE_ASPECT_PLANE_0_BIT_KHR        = IMAGE_ASPECT_PLANE_0_BIT;
const ImageAspectFlags IMAGE_ASPECT_PLANE_1_BIT_KHR        = IMAGE_ASPECT_PLANE_1_BIT;
const ImageAspectFlags IMAGE_ASPECT_PLANE_2_BIT_KHR        = IMAGE_ASPECT_PLANE_2_BIT;
const ImageAspectFlags IMAGE_ASPECT_MEMORY_PLANE_0_BIT_EXT = 0x00000080;
const ImageAspectFlags IMAGE_ASPECT_MEMORY_PLANE_1_BIT_EXT = 0x00000100;
const ImageAspectFlags IMAGE_ASPECT_MEMORY_PLANE_2_BIT_EXT = 0x00000200;
const ImageAspectFlags IMAGE_ASPECT_MEMORY_PLANE_3_BIT_EXT = 0x00000400;
const ImageAspectFlags IMAGE_ASPECT_NONE_KHR               = IMAGE_ASPECT_NONE;

alias SparseMemoryBindFlags = vulkan::vk::VkSparseMemoryBindFlags;
alias SparseMemoryBindFlagBits = SparseMemoryBindFlags;
const SparseMemoryBindFlags SPARSE_MEMORY_BIND_METADATA_BIT = 0x00000001;

alias SparseImageFormatFlags = vulkan::vk::VkSparseImageFormatFlags;
alias SparseImageFormatFlagBits = SparseImageFormatFlags;
const SparseImageFormatFlags SPARSE_IMAGE_FORMAT_SINGLE_MIPTAIL_BIT         = 0x00000001;
const SparseImageFormatFlags SPARSE_IMAGE_FORMAT_ALIGNED_MIP_SIZE_BIT       = 0x00000002;
const SparseImageFormatFlags SPARSE_IMAGE_FORMAT_NONSTANDARD_BLOCK_SIZE_BIT = 0x00000004;

alias SubpassDescriptionFlags = vulkan::vk::VkSubpassDescriptionFlags;
alias SubpassDescriptionFlagBits = SubpassDescriptionFlags;
const SubpassDescriptionFlags SUBPASS_DESCRIPTION_PER_VIEW_ATTRIBUTES_BIT_NVX                           = 0x00000001;
const SubpassDescriptionFlags SUBPASS_DESCRIPTION_PER_VIEW_POSITION_X_ONLY_BIT_NVX                      = 0x00000002;
const SubpassDescriptionFlags SUBPASS_DESCRIPTION_FRAGMENT_REGION_BIT_QCOM                              = SUBPASS_DESCRIPTION_FRAGMENT_REGION_BIT_EXT;
const SubpassDescriptionFlags SUBPASS_DESCRIPTION_SHADER_RESOLVE_BIT_QCOM                               = SUBPASS_DESCRIPTION_CUSTOM_RESOLVE_BIT_EXT;
const SubpassDescriptionFlags SUBPASS_DESCRIPTION_TILE_SHADING_APRON_BIT_QCOM                           = 0x00000100;
const SubpassDescriptionFlags SUBPASS_DESCRIPTION_RASTERIZATION_ORDER_ATTACHMENT_COLOR_ACCESS_BIT_ARM   = SUBPASS_DESCRIPTION_RASTERIZATION_ORDER_ATTACHMENT_COLOR_ACCESS_BIT_EXT;
const SubpassDescriptionFlags SUBPASS_DESCRIPTION_RASTERIZATION_ORDER_ATTACHMENT_DEPTH_ACCESS_BIT_ARM   = SUBPASS_DESCRIPTION_RASTERIZATION_ORDER_ATTACHMENT_DEPTH_ACCESS_BIT_EXT;
const SubpassDescriptionFlags SUBPASS_DESCRIPTION_RASTERIZATION_ORDER_ATTACHMENT_STENCIL_ACCESS_BIT_ARM = SUBPASS_DESCRIPTION_RASTERIZATION_ORDER_ATTACHMENT_STENCIL_ACCESS_BIT_EXT;
const SubpassDescriptionFlags SUBPASS_DESCRIPTION_RASTERIZATION_ORDER_ATTACHMENT_COLOR_ACCESS_BIT_EXT   = 0x00000010;
const SubpassDescriptionFlags SUBPASS_DESCRIPTION_RASTERIZATION_ORDER_ATTACHMENT_DEPTH_ACCESS_BIT_EXT   = 0x00000020;
const SubpassDescriptionFlags SUBPASS_DESCRIPTION_RASTERIZATION_ORDER_ATTACHMENT_STENCIL_ACCESS_BIT_EXT = 0x00000040;
const SubpassDescriptionFlags SUBPASS_DESCRIPTION_ENABLE_LEGACY_DITHERING_BIT_EXT                       = 0x00000080;
const SubpassDescriptionFlags SUBPASS_DESCRIPTION_FRAGMENT_REGION_BIT_EXT                               = 0x00000004;
const SubpassDescriptionFlags SUBPASS_DESCRIPTION_CUSTOM_RESOLVE_BIT_EXT                                = 0x00000008;

alias PipelineStageFlags = vulkan::vk::VkPipelineStageFlags;
alias PipelineStageFlagBits = PipelineStageFlags;
const PipelineStageFlags PIPELINE_STAGE_TOP_OF_PIPE_BIT                          = 0x00000001;
const PipelineStageFlags PIPELINE_STAGE_DRAW_INDIRECT_BIT                        = 0x00000002;
const PipelineStageFlags PIPELINE_STAGE_VERTEX_INPUT_BIT                         = 0x00000004;
const PipelineStageFlags PIPELINE_STAGE_VERTEX_SHADER_BIT                        = 0x00000008;
const PipelineStageFlags PIPELINE_STAGE_TESSELLATION_CONTROL_SHADER_BIT          = 0x00000010;
const PipelineStageFlags PIPELINE_STAGE_TESSELLATION_EVALUATION_SHADER_BIT       = 0x00000020;
const PipelineStageFlags PIPELINE_STAGE_GEOMETRY_SHADER_BIT                      = 0x00000040;
const PipelineStageFlags PIPELINE_STAGE_FRAGMENT_SHADER_BIT                      = 0x00000080;
const PipelineStageFlags PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT                 = 0x00000100;
const PipelineStageFlags PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT                  = 0x00000200;
const PipelineStageFlags PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT              = 0x00000400;
const PipelineStageFlags PIPELINE_STAGE_COMPUTE_SHADER_BIT                       = 0x00000800;
const PipelineStageFlags PIPELINE_STAGE_TRANSFER_BIT                             = 0x00001000;
const PipelineStageFlags PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT                       = 0x00002000;
const PipelineStageFlags PIPELINE_STAGE_HOST_BIT                                 = 0x00004000;
const PipelineStageFlags PIPELINE_STAGE_ALL_GRAPHICS_BIT                         = 0x00008000;
const PipelineStageFlags PIPELINE_STAGE_ALL_COMMANDS_BIT                         = 0x00010000;
const PipelineStageFlags PIPELINE_STAGE_NONE                                     = 0x00000000;
const PipelineStageFlags PIPELINE_STAGE_TRANSFORM_FEEDBACK_BIT_EXT               = 0x01000000;
const PipelineStageFlags PIPELINE_STAGE_CONDITIONAL_RENDERING_BIT_EXT            = 0x00040000;
const PipelineStageFlags PIPELINE_STAGE_ACCELERATION_STRUCTURE_BUILD_BIT_KHR     = 0x02000000;
const PipelineStageFlags PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR               = 0x00200000;
const PipelineStageFlags PIPELINE_STAGE_SHADING_RATE_IMAGE_BIT_NV                = PIPELINE_STAGE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR;
const PipelineStageFlags PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_NV                = PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR;
const PipelineStageFlags PIPELINE_STAGE_ACCELERATION_STRUCTURE_BUILD_BIT_NV      = PIPELINE_STAGE_ACCELERATION_STRUCTURE_BUILD_BIT_KHR;
const PipelineStageFlags PIPELINE_STAGE_TASK_SHADER_BIT_NV                       = PIPELINE_STAGE_TASK_SHADER_BIT_EXT;
const PipelineStageFlags PIPELINE_STAGE_MESH_SHADER_BIT_NV                       = PIPELINE_STAGE_MESH_SHADER_BIT_EXT;
const PipelineStageFlags PIPELINE_STAGE_FRAGMENT_DENSITY_PROCESS_BIT_EXT         = 0x00800000;
const PipelineStageFlags PIPELINE_STAGE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR = 0x00400000;
const PipelineStageFlags PIPELINE_STAGE_COMMAND_PREPROCESS_BIT_NV                = PIPELINE_STAGE_COMMAND_PREPROCESS_BIT_EXT;
const PipelineStageFlags PIPELINE_STAGE_NONE_KHR                                 = PIPELINE_STAGE_NONE;
const PipelineStageFlags PIPELINE_STAGE_TASK_SHADER_BIT_EXT                      = 0x00080000;
const PipelineStageFlags PIPELINE_STAGE_MESH_SHADER_BIT_EXT                      = 0x00100000;
const PipelineStageFlags PIPELINE_STAGE_COMMAND_PREPROCESS_BIT_EXT               = 0x00020000;

alias SampleCountFlags = vulkan::vk::VkSampleCountFlags;
alias SampleCountFlagBits = vulkan::vk::VkSampleCountFlagBits;
const SampleCountFlags SAMPLE_COUNT_1_BIT  = 0x00000001;
const SampleCountFlags SAMPLE_COUNT_2_BIT  = 0x00000002;
const SampleCountFlags SAMPLE_COUNT_4_BIT  = 0x00000004;
const SampleCountFlags SAMPLE_COUNT_8_BIT  = 0x00000008;
const SampleCountFlags SAMPLE_COUNT_16_BIT = 0x00000010;
const SampleCountFlags SAMPLE_COUNT_32_BIT = 0x00000020;
const SampleCountFlags SAMPLE_COUNT_64_BIT = 0x00000040;

alias AttachmentDescriptionFlags = vulkan::vk::VkAttachmentDescriptionFlags;
alias AttachmentDescriptionFlagBits = AttachmentDescriptionFlags;
const AttachmentDescriptionFlags ATTACHMENT_DESCRIPTION_MAY_ALIAS_BIT                            = 0x00000001;
const AttachmentDescriptionFlags ATTACHMENT_DESCRIPTION_RESOLVE_SKIP_TRANSFER_FUNCTION_BIT_KHR   = 0x00000002;
const AttachmentDescriptionFlags ATTACHMENT_DESCRIPTION_RESOLVE_ENABLE_TRANSFER_FUNCTION_BIT_KHR = 0x00000004;

alias StencilFaceFlags = vulkan::vk::VkStencilFaceFlags;
alias StencilFaceFlagBits = StencilFaceFlags;
const StencilFaceFlags STENCIL_FACE_FRONT_BIT      = 0x00000001;
const StencilFaceFlags STENCIL_FACE_BACK_BIT       = 0x00000002;
const StencilFaceFlags STENCIL_FACE_FRONT_AND_BACK = 0x00000003;
const StencilFaceFlags STENCIL_FRONT_AND_BACK      = STENCIL_FACE_FRONT_AND_BACK;

alias CullModeFlags = vulkan::vk::VkCullModeFlags;
alias CullModeFlagBits = CullModeFlags;
const CullModeFlags CULL_MODE_NONE           = 0x00000000;
const CullModeFlags CULL_MODE_FRONT_BIT      = 0x00000001;
const CullModeFlags CULL_MODE_BACK_BIT       = 0x00000002;
const CullModeFlags CULL_MODE_FRONT_AND_BACK = 0x00000003;

alias DescriptorPoolCreateFlags = vulkan::vk::VkDescriptorPoolCreateFlags;
alias DescriptorPoolCreateFlagBits = DescriptorPoolCreateFlags;
const DescriptorPoolCreateFlags DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT           = 0x00000001;
const DescriptorPoolCreateFlags DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT             = 0x00000002;
const DescriptorPoolCreateFlags DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT_EXT         = DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT;
const DescriptorPoolCreateFlags DESCRIPTOR_POOL_CREATE_HOST_ONLY_BIT_VALVE               = DESCRIPTOR_POOL_CREATE_HOST_ONLY_BIT_EXT;
const DescriptorPoolCreateFlags DESCRIPTOR_POOL_CREATE_HOST_ONLY_BIT_EXT                 = 0x00000004;
const DescriptorPoolCreateFlags DESCRIPTOR_POOL_CREATE_ALLOW_OVERALLOCATION_SETS_BIT_NV  = 0x00000008;
const DescriptorPoolCreateFlags DESCRIPTOR_POOL_CREATE_ALLOW_OVERALLOCATION_POOLS_BIT_NV = 0x00000010;

alias DescriptorPoolResetFlags = vulkan::vk::VkDescriptorPoolResetFlags;

alias DependencyFlags = vulkan::vk::VkDependencyFlags;
alias DependencyFlagBits = DependencyFlags;
const DependencyFlags DEPENDENCY_BY_REGION_BIT                                          = 0x00000001;
const DependencyFlags DEPENDENCY_DEVICE_GROUP_BIT                                       = 0x00000004;
const DependencyFlags DEPENDENCY_VIEW_LOCAL_BIT                                         = 0x00000002;
const DependencyFlags DEPENDENCY_VIEW_LOCAL_BIT_KHR                                     = DEPENDENCY_VIEW_LOCAL_BIT;
const DependencyFlags DEPENDENCY_DEVICE_GROUP_BIT_KHR                                   = DEPENDENCY_DEVICE_GROUP_BIT;
const DependencyFlags DEPENDENCY_FEEDBACK_LOOP_BIT_EXT                                  = 0x00000008;
const DependencyFlags DEPENDENCY_QUEUE_FAMILY_OWNERSHIP_TRANSFER_USE_ALL_STAGES_BIT_KHR = 0x00000020;
const DependencyFlags DEPENDENCY_ASYMMETRIC_EVENT_BIT_KHR                               = 0x00000040;

alias SubgroupFeatureFlags = vulkan::vk::VkSubgroupFeatureFlags;
alias SubgroupFeatureFlagBits = SubgroupFeatureFlags;
const SubgroupFeatureFlags SUBGROUP_FEATURE_BASIC_BIT                = 0x00000001;
const SubgroupFeatureFlags SUBGROUP_FEATURE_VOTE_BIT                 = 0x00000002;
const SubgroupFeatureFlags SUBGROUP_FEATURE_ARITHMETIC_BIT           = 0x00000004;
const SubgroupFeatureFlags SUBGROUP_FEATURE_BALLOT_BIT               = 0x00000008;
const SubgroupFeatureFlags SUBGROUP_FEATURE_SHUFFLE_BIT              = 0x00000010;
const SubgroupFeatureFlags SUBGROUP_FEATURE_SHUFFLE_RELATIVE_BIT     = 0x00000020;
const SubgroupFeatureFlags SUBGROUP_FEATURE_CLUSTERED_BIT            = 0x00000040;
const SubgroupFeatureFlags SUBGROUP_FEATURE_QUAD_BIT                 = 0x00000080;
const SubgroupFeatureFlags SUBGROUP_FEATURE_ROTATE_BIT               = 0x00000200;
const SubgroupFeatureFlags SUBGROUP_FEATURE_ROTATE_CLUSTERED_BIT     = 0x00000400;
const SubgroupFeatureFlags SUBGROUP_FEATURE_PARTITIONED_BIT_NV       = SUBGROUP_FEATURE_PARTITIONED_BIT_EXT;
const SubgroupFeatureFlags SUBGROUP_FEATURE_ROTATE_BIT_KHR           = SUBGROUP_FEATURE_ROTATE_BIT;
const SubgroupFeatureFlags SUBGROUP_FEATURE_ROTATE_CLUSTERED_BIT_KHR = SUBGROUP_FEATURE_ROTATE_CLUSTERED_BIT;
const SubgroupFeatureFlags SUBGROUP_FEATURE_PARTITIONED_BIT_EXT      = 0x00000100;

typedef IndirectCommandsLayoutUsageFlagsNV @constinit = uint;
alias IndirectCommandsLayoutUsageFlagBitsNV = IndirectCommandsLayoutUsageFlagsNV;
const IndirectCommandsLayoutUsageFlagsNV INDIRECT_COMMANDS_LAYOUT_USAGE_EXPLICIT_PREPROCESS_BIT_NV = 0x00000001;
const IndirectCommandsLayoutUsageFlagsNV INDIRECT_COMMANDS_LAYOUT_USAGE_INDEXED_SEQUENCES_BIT_NV   = 0x00000002;
const IndirectCommandsLayoutUsageFlagsNV INDIRECT_COMMANDS_LAYOUT_USAGE_UNORDERED_SEQUENCES_BIT_NV = 0x00000004;

typedef IndirectStateFlagsNV @constinit = uint;
alias IndirectStateFlagBitsNV = IndirectStateFlagsNV;
const IndirectStateFlagsNV INDIRECT_STATE_FLAG_FRONTFACE_BIT_NV = 0x00000001;

typedef GeometryFlagsKHR @constinit = uint;
alias GeometryFlagBitsKHR = GeometryFlagsKHR;
const GeometryFlagsKHR GEOMETRY_OPAQUE_BIT_KHR                          = 0x00000001;
const GeometryFlagsKHR GEOMETRY_NO_DUPLICATE_ANY_HIT_INVOCATION_BIT_KHR = 0x00000002;
const GeometryFlagsKHR GEOMETRY_OPAQUE_BIT_NV                           = GEOMETRY_OPAQUE_BIT_KHR;
const GeometryFlagsKHR GEOMETRY_NO_DUPLICATE_ANY_HIT_INVOCATION_BIT_NV  = GEOMETRY_NO_DUPLICATE_ANY_HIT_INVOCATION_BIT_KHR;

typedef GeometryInstanceFlagsKHR @constinit = uint;
alias GeometryInstanceFlagBitsKHR = GeometryInstanceFlagsKHR;
const GeometryInstanceFlagsKHR GEOMETRY_INSTANCE_TRIANGLE_FACING_CULL_DISABLE_BIT_KHR    = 0x00000001;
const GeometryInstanceFlagsKHR GEOMETRY_INSTANCE_TRIANGLE_FLIP_FACING_BIT_KHR            = 0x00000002;
const GeometryInstanceFlagsKHR GEOMETRY_INSTANCE_FORCE_OPAQUE_BIT_KHR                    = 0x00000004;
const GeometryInstanceFlagsKHR GEOMETRY_INSTANCE_FORCE_NO_OPAQUE_BIT_KHR                 = 0x00000008;
const GeometryInstanceFlagsKHR GEOMETRY_INSTANCE_TRIANGLE_FRONT_COUNTERCLOCKWISE_BIT_KHR = GEOMETRY_INSTANCE_TRIANGLE_FLIP_FACING_BIT_KHR;
const GeometryInstanceFlagsKHR GEOMETRY_INSTANCE_TRIANGLE_CULL_DISABLE_BIT_NV            = GEOMETRY_INSTANCE_TRIANGLE_FACING_CULL_DISABLE_BIT_KHR;
const GeometryInstanceFlagsKHR GEOMETRY_INSTANCE_TRIANGLE_FRONT_COUNTERCLOCKWISE_BIT_NV  = GEOMETRY_INSTANCE_TRIANGLE_FRONT_COUNTERCLOCKWISE_BIT_KHR;
const GeometryInstanceFlagsKHR GEOMETRY_INSTANCE_FORCE_OPAQUE_BIT_NV                     = GEOMETRY_INSTANCE_FORCE_OPAQUE_BIT_KHR;
const GeometryInstanceFlagsKHR GEOMETRY_INSTANCE_FORCE_NO_OPAQUE_BIT_NV                  = GEOMETRY_INSTANCE_FORCE_NO_OPAQUE_BIT_KHR;
const GeometryInstanceFlagsKHR GEOMETRY_INSTANCE_FORCE_OPACITY_MICROMAP_2_STATE_BIT_EXT  = 0x00000010;
const GeometryInstanceFlagsKHR GEOMETRY_INSTANCE_FORCE_OPACITY_MICROMAP_2_STATE_EXT      = GEOMETRY_INSTANCE_FORCE_OPACITY_MICROMAP_2_STATE_BIT_EXT;
const GeometryInstanceFlagsKHR GEOMETRY_INSTANCE_DISABLE_OPACITY_MICROMAPS_BIT_EXT       = 0x00000020;
const GeometryInstanceFlagsKHR GEOMETRY_INSTANCE_DISABLE_OPACITY_MICROMAPS_EXT           = GEOMETRY_INSTANCE_DISABLE_OPACITY_MICROMAPS_BIT_EXT;

typedef ClusterAccelerationStructureGeometryFlagsNV @constinit = uint;
alias ClusterAccelerationStructureGeometryFlagBitsNV = ClusterAccelerationStructureGeometryFlagsNV;
const ClusterAccelerationStructureGeometryFlagsNV CLUSTER_ACCELERATION_STRUCTURE_GEOMETRY_CULL_DISABLE_BIT_NV                   = 0x00000001;
const ClusterAccelerationStructureGeometryFlagsNV CLUSTER_ACCELERATION_STRUCTURE_GEOMETRY_NO_DUPLICATE_ANYHIT_INVOCATION_BIT_NV = 0x00000002;
const ClusterAccelerationStructureGeometryFlagsNV CLUSTER_ACCELERATION_STRUCTURE_GEOMETRY_OPAQUE_BIT_NV                         = 0x00000004;

typedef ClusterAccelerationStructureClusterFlagsNV @constinit = uint;
alias ClusterAccelerationStructureClusterFlagBitsNV = ClusterAccelerationStructureClusterFlagsNV;
const ClusterAccelerationStructureClusterFlagsNV CLUSTER_ACCELERATION_STRUCTURE_CLUSTER_ALLOW_DISABLE_OPACITY_MICROMAPS_NV = 0x00000001;

typedef ClusterAccelerationStructureAddressResolutionFlagsNV @constinit = uint;
alias ClusterAccelerationStructureAddressResolutionFlagBitsNV = ClusterAccelerationStructureAddressResolutionFlagsNV;
const ClusterAccelerationStructureAddressResolutionFlagsNV CLUSTER_ACCELERATION_STRUCTURE_ADDRESS_RESOLUTION_NONE_NV                             = 0x00000000;
const ClusterAccelerationStructureAddressResolutionFlagsNV CLUSTER_ACCELERATION_STRUCTURE_ADDRESS_RESOLUTION_INDIRECTED_DST_IMPLICIT_DATA_BIT_NV = 0x00000001;
const ClusterAccelerationStructureAddressResolutionFlagsNV CLUSTER_ACCELERATION_STRUCTURE_ADDRESS_RESOLUTION_INDIRECTED_SCRATCH_DATA_BIT_NV      = 0x00000002;
const ClusterAccelerationStructureAddressResolutionFlagsNV CLUSTER_ACCELERATION_STRUCTURE_ADDRESS_RESOLUTION_INDIRECTED_DST_ADDRESS_ARRAY_BIT_NV = 0x00000004;
const ClusterAccelerationStructureAddressResolutionFlagsNV CLUSTER_ACCELERATION_STRUCTURE_ADDRESS_RESOLUTION_INDIRECTED_DST_SIZES_ARRAY_BIT_NV   = 0x00000008;
const ClusterAccelerationStructureAddressResolutionFlagsNV CLUSTER_ACCELERATION_STRUCTURE_ADDRESS_RESOLUTION_INDIRECTED_SRC_INFOS_ARRAY_BIT_NV   = 0x00000010;
const ClusterAccelerationStructureAddressResolutionFlagsNV CLUSTER_ACCELERATION_STRUCTURE_ADDRESS_RESOLUTION_INDIRECTED_SRC_INFOS_COUNT_BIT_NV   = 0x00000020;

typedef BuildAccelerationStructureFlagsKHR @constinit = uint;
alias BuildAccelerationStructureFlagBitsKHR = BuildAccelerationStructureFlagsKHR;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_ALLOW_UPDATE_BIT_KHR                       = 0x00000001;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_ALLOW_COMPACTION_BIT_KHR                   = 0x00000002;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR                  = 0x00000004;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_BUILD_BIT_KHR                  = 0x00000008;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_LOW_MEMORY_BIT_KHR                         = 0x00000010;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_ALLOW_UPDATE_BIT_NV                        = BUILD_ACCELERATION_STRUCTURE_ALLOW_UPDATE_BIT_KHR;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_ALLOW_COMPACTION_BIT_NV                    = BUILD_ACCELERATION_STRUCTURE_ALLOW_COMPACTION_BIT_KHR;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_NV                   = BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_BUILD_BIT_NV                   = BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_BUILD_BIT_KHR;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_LOW_MEMORY_BIT_NV                          = BUILD_ACCELERATION_STRUCTURE_LOW_MEMORY_BIT_KHR;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_MOTION_BIT_NV                              = 0x00000020;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_ALLOW_OPACITY_MICROMAP_UPDATE_BIT_EXT      = 0x00000040;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_ALLOW_OPACITY_MICROMAP_UPDATE_EXT          = BUILD_ACCELERATION_STRUCTURE_ALLOW_OPACITY_MICROMAP_UPDATE_BIT_EXT;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_ALLOW_DISABLE_OPACITY_MICROMAPS_BIT_EXT    = 0x00000080;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_ALLOW_DISABLE_OPACITY_MICROMAPS_EXT        = BUILD_ACCELERATION_STRUCTURE_ALLOW_DISABLE_OPACITY_MICROMAPS_BIT_EXT;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_ALLOW_OPACITY_MICROMAP_DATA_UPDATE_BIT_EXT = 0x00000100;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_ALLOW_OPACITY_MICROMAP_DATA_UPDATE_EXT     = BUILD_ACCELERATION_STRUCTURE_ALLOW_OPACITY_MICROMAP_DATA_UPDATE_BIT_EXT;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_ALLOW_DATA_ACCESS_BIT_KHR                  = 0x00000800;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_ALLOW_DATA_ACCESS_KHR                      = BUILD_ACCELERATION_STRUCTURE_ALLOW_DATA_ACCESS_BIT_KHR;
const BuildAccelerationStructureFlagsKHR BUILD_ACCELERATION_STRUCTURE_ALLOW_CLUSTER_OPACITY_MICROMAPS_BIT_NV     = 0x00001000;

alias PrivateDataSlotCreateFlags = vulkan::vk::VkPrivateDataSlotCreateFlags;

typedef AccelerationStructureCreateFlagsKHR @constinit = uint;
alias AccelerationStructureCreateFlagBitsKHR = AccelerationStructureCreateFlagsKHR;
const AccelerationStructureCreateFlagsKHR ACCELERATION_STRUCTURE_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT_KHR    = 0x00000001;
const AccelerationStructureCreateFlagsKHR ACCELERATION_STRUCTURE_CREATE_DESCRIPTOR_BUFFER_CAPTURE_REPLAY_BIT_EXT = 0x00000008;
const AccelerationStructureCreateFlagsKHR ACCELERATION_STRUCTURE_CREATE_MOTION_BIT_NV                            = 0x00000004;

alias DescriptorUpdateTemplateCreateFlags = vulkan::vk::VkDescriptorUpdateTemplateCreateFlags;

alias PipelineCreationFeedbackFlags = vulkan::vk::VkPipelineCreationFeedbackFlags;
alias PipelineCreationFeedbackFlagBits = PipelineCreationFeedbackFlags;
const PipelineCreationFeedbackFlags PIPELINE_CREATION_FEEDBACK_VALID_BIT                              = 0x00000001;
const PipelineCreationFeedbackFlags PIPELINE_CREATION_FEEDBACK_APPLICATION_PIPELINE_CACHE_HIT_BIT     = 0x00000002;
const PipelineCreationFeedbackFlags PIPELINE_CREATION_FEEDBACK_BASE_PIPELINE_ACCELERATION_BIT         = 0x00000004;
const PipelineCreationFeedbackFlags PIPELINE_CREATION_FEEDBACK_VALID_BIT_EXT                          = PIPELINE_CREATION_FEEDBACK_VALID_BIT;
const PipelineCreationFeedbackFlags PIPELINE_CREATION_FEEDBACK_APPLICATION_PIPELINE_CACHE_HIT_BIT_EXT = PIPELINE_CREATION_FEEDBACK_APPLICATION_PIPELINE_CACHE_HIT_BIT;
const PipelineCreationFeedbackFlags PIPELINE_CREATION_FEEDBACK_BASE_PIPELINE_ACCELERATION_BIT_EXT     = PIPELINE_CREATION_FEEDBACK_BASE_PIPELINE_ACCELERATION_BIT;

typedef PerformanceCounterDescriptionFlagsKHR @constinit = uint;
alias PerformanceCounterDescriptionFlagBitsKHR = PerformanceCounterDescriptionFlagsKHR;
const PerformanceCounterDescriptionFlagsKHR PERFORMANCE_COUNTER_DESCRIPTION_PERFORMANCE_IMPACTING_BIT_KHR = 0x00000001;
const PerformanceCounterDescriptionFlagsKHR PERFORMANCE_COUNTER_DESCRIPTION_PERFORMANCE_IMPACTING_KHR     = PERFORMANCE_COUNTER_DESCRIPTION_PERFORMANCE_IMPACTING_BIT_KHR;
const PerformanceCounterDescriptionFlagsKHR PERFORMANCE_COUNTER_DESCRIPTION_CONCURRENTLY_IMPACTED_BIT_KHR = 0x00000002;
const PerformanceCounterDescriptionFlagsKHR PERFORMANCE_COUNTER_DESCRIPTION_CONCURRENTLY_IMPACTED_KHR     = PERFORMANCE_COUNTER_DESCRIPTION_CONCURRENTLY_IMPACTED_BIT_KHR;

typedef AcquireProfilingLockFlagsKHR @constinit = uint;
alias AcquireProfilingLockFlagBitsKHR = AcquireProfilingLockFlagsKHR;

alias SemaphoreWaitFlags = vulkan::vk::VkSemaphoreWaitFlags;
alias SemaphoreWaitFlagBits = SemaphoreWaitFlags;
const SemaphoreWaitFlags SEMAPHORE_WAIT_ANY_BIT     = 0x00000001;
const SemaphoreWaitFlags SEMAPHORE_WAIT_ANY_BIT_KHR = SEMAPHORE_WAIT_ANY_BIT;

typedef PipelineCompilerControlFlagsAMD @constinit = uint;
alias PipelineCompilerControlFlagBitsAMD = PipelineCompilerControlFlagsAMD;

typedef ShaderCorePropertiesFlagsAMD @constinit = uint;
alias ShaderCorePropertiesFlagBitsAMD = ShaderCorePropertiesFlagsAMD;

typedef DeviceDiagnosticsConfigFlagsNV @constinit = uint;
alias DeviceDiagnosticsConfigFlagBitsNV = DeviceDiagnosticsConfigFlagsNV;
const DeviceDiagnosticsConfigFlagsNV DEVICE_DIAGNOSTICS_CONFIG_ENABLE_SHADER_DEBUG_INFO_BIT_NV      = 0x00000001;
const DeviceDiagnosticsConfigFlagsNV DEVICE_DIAGNOSTICS_CONFIG_ENABLE_RESOURCE_TRACKING_BIT_NV      = 0x00000002;
const DeviceDiagnosticsConfigFlagsNV DEVICE_DIAGNOSTICS_CONFIG_ENABLE_AUTOMATIC_CHECKPOINTS_BIT_NV  = 0x00000004;
const DeviceDiagnosticsConfigFlagsNV DEVICE_DIAGNOSTICS_CONFIG_ENABLE_SHADER_ERROR_REPORTING_BIT_NV = 0x00000008;

alias AccessFlags2 = vulkan::vk::VkAccessFlags2;
alias AccessFlagBits2 = AccessFlags2;
const AccessFlags2 ACCESS_2_NONE                                          = 0x0000000000000000;
const AccessFlags2 ACCESS_2_INDIRECT_COMMAND_READ_BIT                     = 0x0000000000000001;
const AccessFlags2 ACCESS_2_INDEX_READ_BIT                                = 0x0000000000000002;
const AccessFlags2 ACCESS_2_VERTEX_ATTRIBUTE_READ_BIT                     = 0x0000000000000004;
const AccessFlags2 ACCESS_2_UNIFORM_READ_BIT                              = 0x0000000000000008;
const AccessFlags2 ACCESS_2_INPUT_ATTACHMENT_READ_BIT                     = 0x0000000000000010;
const AccessFlags2 ACCESS_2_SHADER_READ_BIT                               = 0x0000000000000020;
const AccessFlags2 ACCESS_2_SHADER_WRITE_BIT                              = 0x0000000000000040;
const AccessFlags2 ACCESS_2_COLOR_ATTACHMENT_READ_BIT                     = 0x0000000000000080;
const AccessFlags2 ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT                    = 0x0000000000000100;
const AccessFlags2 ACCESS_2_DEPTH_STENCIL_ATTACHMENT_READ_BIT             = 0x0000000000000200;
const AccessFlags2 ACCESS_2_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT            = 0x0000000000000400;
const AccessFlags2 ACCESS_2_TRANSFER_READ_BIT                             = 0x0000000000000800;
const AccessFlags2 ACCESS_2_TRANSFER_WRITE_BIT                            = 0x0000000000001000;
const AccessFlags2 ACCESS_2_HOST_READ_BIT                                 = 0x0000000000002000;
const AccessFlags2 ACCESS_2_HOST_WRITE_BIT                                = 0x0000000000004000;
const AccessFlags2 ACCESS_2_MEMORY_READ_BIT                               = 0x0000000000008000;
const AccessFlags2 ACCESS_2_MEMORY_WRITE_BIT                              = 0x0000000000010000;
const AccessFlags2 ACCESS_2_SHADER_SAMPLED_READ_BIT                       = 0x0000000100000000;
const AccessFlags2 ACCESS_2_SHADER_STORAGE_READ_BIT                       = 0x0000000200000000;
const AccessFlags2 ACCESS_2_SHADER_STORAGE_WRITE_BIT                      = 0x0000000400000000;
const AccessFlags2 ACCESS_2_SAMPLER_HEAP_READ_BIT_EXT                     = 0x0200000000000000;
const AccessFlags2 ACCESS_2_RESOURCE_HEAP_READ_BIT_EXT                    = 0x0400000000000000;
const AccessFlags2 ACCESS_2_SHADER_TILE_ATTACHMENT_READ_BIT_QCOM          = 0x0008000000000000;
const AccessFlags2 ACCESS_2_SHADER_TILE_ATTACHMENT_WRITE_BIT_QCOM         = 0x0010000000000000;
const AccessFlags2 ACCESS_2_NONE_KHR                                      = ACCESS_2_NONE;
const AccessFlags2 ACCESS_2_INDIRECT_COMMAND_READ_BIT_KHR                 = ACCESS_2_INDIRECT_COMMAND_READ_BIT;
const AccessFlags2 ACCESS_2_INDEX_READ_BIT_KHR                            = ACCESS_2_INDEX_READ_BIT;
const AccessFlags2 ACCESS_2_VERTEX_ATTRIBUTE_READ_BIT_KHR                 = ACCESS_2_VERTEX_ATTRIBUTE_READ_BIT;
const AccessFlags2 ACCESS_2_UNIFORM_READ_BIT_KHR                          = ACCESS_2_UNIFORM_READ_BIT;
const AccessFlags2 ACCESS_2_INPUT_ATTACHMENT_READ_BIT_KHR                 = ACCESS_2_INPUT_ATTACHMENT_READ_BIT;
const AccessFlags2 ACCESS_2_SHADER_READ_BIT_KHR                           = ACCESS_2_SHADER_READ_BIT;
const AccessFlags2 ACCESS_2_SHADER_WRITE_BIT_KHR                          = ACCESS_2_SHADER_WRITE_BIT;
const AccessFlags2 ACCESS_2_COLOR_ATTACHMENT_READ_BIT_KHR                 = ACCESS_2_COLOR_ATTACHMENT_READ_BIT;
const AccessFlags2 ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT_KHR                = ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT;
const AccessFlags2 ACCESS_2_DEPTH_STENCIL_ATTACHMENT_READ_BIT_KHR         = ACCESS_2_DEPTH_STENCIL_ATTACHMENT_READ_BIT;
const AccessFlags2 ACCESS_2_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT_KHR        = ACCESS_2_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
const AccessFlags2 ACCESS_2_TRANSFER_READ_BIT_KHR                         = ACCESS_2_TRANSFER_READ_BIT;
const AccessFlags2 ACCESS_2_TRANSFER_WRITE_BIT_KHR                        = ACCESS_2_TRANSFER_WRITE_BIT;
const AccessFlags2 ACCESS_2_HOST_READ_BIT_KHR                             = ACCESS_2_HOST_READ_BIT;
const AccessFlags2 ACCESS_2_HOST_WRITE_BIT_KHR                            = ACCESS_2_HOST_WRITE_BIT;
const AccessFlags2 ACCESS_2_MEMORY_READ_BIT_KHR                           = ACCESS_2_MEMORY_READ_BIT;
const AccessFlags2 ACCESS_2_MEMORY_WRITE_BIT_KHR                          = ACCESS_2_MEMORY_WRITE_BIT;
const AccessFlags2 ACCESS_2_SHADER_SAMPLED_READ_BIT_KHR                   = ACCESS_2_SHADER_SAMPLED_READ_BIT;
const AccessFlags2 ACCESS_2_SHADER_STORAGE_READ_BIT_KHR                   = ACCESS_2_SHADER_STORAGE_READ_BIT;
const AccessFlags2 ACCESS_2_SHADER_STORAGE_WRITE_BIT_KHR                  = ACCESS_2_SHADER_STORAGE_WRITE_BIT;
const AccessFlags2 ACCESS_2_TRANSFORM_FEEDBACK_WRITE_BIT_EXT              = 0x0000000002000000;
const AccessFlags2 ACCESS_2_TRANSFORM_FEEDBACK_COUNTER_READ_BIT_EXT       = 0x0000000004000000;
const AccessFlags2 ACCESS_2_TRANSFORM_FEEDBACK_COUNTER_WRITE_BIT_EXT      = 0x0000000008000000;
const AccessFlags2 ACCESS_2_CONDITIONAL_RENDERING_READ_BIT_EXT            = 0x0000000000100000;
const AccessFlags2 ACCESS_2_COMMAND_PREPROCESS_READ_BIT_NV                = ACCESS_2_COMMAND_PREPROCESS_READ_BIT_EXT;
const AccessFlags2 ACCESS_2_COMMAND_PREPROCESS_WRITE_BIT_NV               = ACCESS_2_COMMAND_PREPROCESS_WRITE_BIT_EXT;
const AccessFlags2 ACCESS_2_COMMAND_PREPROCESS_READ_BIT_EXT               = 0x0000000000020000;
const AccessFlags2 ACCESS_2_COMMAND_PREPROCESS_WRITE_BIT_EXT              = 0x0000000000040000;
const AccessFlags2 ACCESS_2_FRAGMENT_SHADING_RATE_ATTACHMENT_READ_BIT_KHR = 0x0000000000800000;
const AccessFlags2 ACCESS_2_SHADING_RATE_IMAGE_READ_BIT_NV                = ACCESS_2_FRAGMENT_SHADING_RATE_ATTACHMENT_READ_BIT_KHR;
const AccessFlags2 ACCESS_2_ACCELERATION_STRUCTURE_READ_BIT_KHR           = 0x0000000000200000;
const AccessFlags2 ACCESS_2_ACCELERATION_STRUCTURE_WRITE_BIT_KHR          = 0x0000000000400000;
const AccessFlags2 ACCESS_2_ACCELERATION_STRUCTURE_READ_BIT_NV            = ACCESS_2_ACCELERATION_STRUCTURE_READ_BIT_KHR;
const AccessFlags2 ACCESS_2_ACCELERATION_STRUCTURE_WRITE_BIT_NV           = ACCESS_2_ACCELERATION_STRUCTURE_WRITE_BIT_KHR;
const AccessFlags2 ACCESS_2_FRAGMENT_DENSITY_MAP_READ_BIT_EXT             = 0x0000000001000000;
const AccessFlags2 ACCESS_2_COLOR_ATTACHMENT_READ_NONCOHERENT_BIT_EXT     = 0x0000000000080000;
const AccessFlags2 ACCESS_2_DESCRIPTOR_BUFFER_READ_BIT_EXT                = 0x0000020000000000;
const AccessFlags2 ACCESS_2_INVOCATION_MASK_READ_BIT_HUAWEI               = 0x0000008000000000;
const AccessFlags2 ACCESS_2_SHADER_BINDING_TABLE_READ_BIT_KHR             = 0x0000010000000000;
const AccessFlags2 ACCESS_2_MICROMAP_READ_BIT_EXT                         = 0x0000100000000000;
const AccessFlags2 ACCESS_2_MICROMAP_WRITE_BIT_EXT                        = 0x0000200000000000;
const AccessFlags2 ACCESS_2_OPTICAL_FLOW_READ_BIT_NV                      = 0x0000040000000000;
const AccessFlags2 ACCESS_2_OPTICAL_FLOW_WRITE_BIT_NV                     = 0x0000080000000000;
const AccessFlags2 ACCESS_2_DATA_GRAPH_READ_BIT_ARM                       = 0x0000800000000000;
const AccessFlags2 ACCESS_2_DATA_GRAPH_WRITE_BIT_ARM                      = 0x0001000000000000;
const AccessFlags2 ACCESS_2_MEMORY_DECOMPRESSION_READ_BIT_EXT             = 0x0080000000000000;
const AccessFlags2 ACCESS_2_MEMORY_DECOMPRESSION_WRITE_BIT_EXT            = 0x0100000000000000;

alias PipelineStageFlags2 = vulkan::vk::VkPipelineStageFlags2;
alias PipelineStageFlagBits2 = PipelineStageFlags2;
const PipelineStageFlags2 PIPELINE_STAGE_2_NONE                                     = 0x0000000000000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_TOP_OF_PIPE_BIT                          = 0x0000000000000001;
const PipelineStageFlags2 PIPELINE_STAGE_2_DRAW_INDIRECT_BIT                        = 0x0000000000000002;
const PipelineStageFlags2 PIPELINE_STAGE_2_VERTEX_INPUT_BIT                         = 0x0000000000000004;
const PipelineStageFlags2 PIPELINE_STAGE_2_VERTEX_SHADER_BIT                        = 0x0000000000000008;
const PipelineStageFlags2 PIPELINE_STAGE_2_TESSELLATION_CONTROL_SHADER_BIT          = 0x0000000000000010;
const PipelineStageFlags2 PIPELINE_STAGE_2_TESSELLATION_EVALUATION_SHADER_BIT       = 0x0000000000000020;
const PipelineStageFlags2 PIPELINE_STAGE_2_GEOMETRY_SHADER_BIT                      = 0x0000000000000040;
const PipelineStageFlags2 PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT                      = 0x0000000000000080;
const PipelineStageFlags2 PIPELINE_STAGE_2_EARLY_FRAGMENT_TESTS_BIT                 = 0x0000000000000100;
const PipelineStageFlags2 PIPELINE_STAGE_2_LATE_FRAGMENT_TESTS_BIT                  = 0x0000000000000200;
const PipelineStageFlags2 PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT              = 0x0000000000000400;
const PipelineStageFlags2 PIPELINE_STAGE_2_COMPUTE_SHADER_BIT                       = 0x0000000000000800;
const PipelineStageFlags2 PIPELINE_STAGE_2_ALL_TRANSFER_BIT                         = 0x0000000000001000;
const PipelineStageFlags2 PIPELINE_STAGE_2_TRANSFER_BIT                             = PIPELINE_STAGE_2_ALL_TRANSFER_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_BOTTOM_OF_PIPE_BIT                       = 0x0000000000002000;
const PipelineStageFlags2 PIPELINE_STAGE_2_HOST_BIT                                 = 0x0000000000004000;
const PipelineStageFlags2 PIPELINE_STAGE_2_ALL_GRAPHICS_BIT                         = 0x0000000000008000;
const PipelineStageFlags2 PIPELINE_STAGE_2_ALL_COMMANDS_BIT                         = 0x0000000000010000;
const PipelineStageFlags2 PIPELINE_STAGE_2_COPY_BIT                                 = 0x0000000100000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_RESOLVE_BIT                              = 0x0000000200000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_BLIT_BIT                                 = 0x0000000400000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_CLEAR_BIT                                = 0x0000000800000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_INDEX_INPUT_BIT                          = 0x0000001000000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_VERTEX_ATTRIBUTE_INPUT_BIT               = 0x0000002000000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_PRE_RASTERIZATION_SHADERS_BIT            = 0x0000004000000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_NONE_KHR                                 = PIPELINE_STAGE_2_NONE;
const PipelineStageFlags2 PIPELINE_STAGE_2_TOP_OF_PIPE_BIT_KHR                      = PIPELINE_STAGE_2_TOP_OF_PIPE_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_DRAW_INDIRECT_BIT_KHR                    = PIPELINE_STAGE_2_DRAW_INDIRECT_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_VERTEX_INPUT_BIT_KHR                     = PIPELINE_STAGE_2_VERTEX_INPUT_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_VERTEX_SHADER_BIT_KHR                    = PIPELINE_STAGE_2_VERTEX_SHADER_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_TESSELLATION_CONTROL_SHADER_BIT_KHR      = PIPELINE_STAGE_2_TESSELLATION_CONTROL_SHADER_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_TESSELLATION_EVALUATION_SHADER_BIT_KHR   = PIPELINE_STAGE_2_TESSELLATION_EVALUATION_SHADER_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_GEOMETRY_SHADER_BIT_KHR                  = PIPELINE_STAGE_2_GEOMETRY_SHADER_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT_KHR                  = PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_EARLY_FRAGMENT_TESTS_BIT_KHR             = PIPELINE_STAGE_2_EARLY_FRAGMENT_TESTS_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_LATE_FRAGMENT_TESTS_BIT_KHR              = PIPELINE_STAGE_2_LATE_FRAGMENT_TESTS_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT_KHR          = PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_COMPUTE_SHADER_BIT_KHR                   = PIPELINE_STAGE_2_COMPUTE_SHADER_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_ALL_TRANSFER_BIT_KHR                     = PIPELINE_STAGE_2_ALL_TRANSFER_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_TRANSFER_BIT_KHR                         = PIPELINE_STAGE_2_ALL_TRANSFER_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_BOTTOM_OF_PIPE_BIT_KHR                   = PIPELINE_STAGE_2_BOTTOM_OF_PIPE_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_HOST_BIT_KHR                             = PIPELINE_STAGE_2_HOST_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_ALL_GRAPHICS_BIT_KHR                     = PIPELINE_STAGE_2_ALL_GRAPHICS_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_ALL_COMMANDS_BIT_KHR                     = PIPELINE_STAGE_2_ALL_COMMANDS_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_COPY_BIT_KHR                             = PIPELINE_STAGE_2_COPY_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_RESOLVE_BIT_KHR                          = PIPELINE_STAGE_2_RESOLVE_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_BLIT_BIT_KHR                             = PIPELINE_STAGE_2_BLIT_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_CLEAR_BIT_KHR                            = PIPELINE_STAGE_2_CLEAR_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_INDEX_INPUT_BIT_KHR                      = PIPELINE_STAGE_2_INDEX_INPUT_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_VERTEX_ATTRIBUTE_INPUT_BIT_KHR           = PIPELINE_STAGE_2_VERTEX_ATTRIBUTE_INPUT_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_PRE_RASTERIZATION_SHADERS_BIT_KHR        = PIPELINE_STAGE_2_PRE_RASTERIZATION_SHADERS_BIT;
const PipelineStageFlags2 PIPELINE_STAGE_2_TRANSFORM_FEEDBACK_BIT_EXT               = 0x0000000001000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_CONDITIONAL_RENDERING_BIT_EXT            = 0x0000000000040000;
const PipelineStageFlags2 PIPELINE_STAGE_2_COMMAND_PREPROCESS_BIT_NV                = PIPELINE_STAGE_2_COMMAND_PREPROCESS_BIT_EXT;
const PipelineStageFlags2 PIPELINE_STAGE_2_COMMAND_PREPROCESS_BIT_EXT               = 0x0000000000020000;
const PipelineStageFlags2 PIPELINE_STAGE_2_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR = 0x0000000000400000;
const PipelineStageFlags2 PIPELINE_STAGE_2_SHADING_RATE_IMAGE_BIT_NV                = PIPELINE_STAGE_2_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR;
const PipelineStageFlags2 PIPELINE_STAGE_2_ACCELERATION_STRUCTURE_BUILD_BIT_KHR     = 0x0000000002000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_RAY_TRACING_SHADER_BIT_KHR               = 0x0000000000200000;
const PipelineStageFlags2 PIPELINE_STAGE_2_RAY_TRACING_SHADER_BIT_NV                = PIPELINE_STAGE_2_RAY_TRACING_SHADER_BIT_KHR;
const PipelineStageFlags2 PIPELINE_STAGE_2_ACCELERATION_STRUCTURE_BUILD_BIT_NV      = PIPELINE_STAGE_2_ACCELERATION_STRUCTURE_BUILD_BIT_KHR;
const PipelineStageFlags2 PIPELINE_STAGE_2_FRAGMENT_DENSITY_PROCESS_BIT_EXT         = 0x0000000000800000;
const PipelineStageFlags2 PIPELINE_STAGE_2_TASK_SHADER_BIT_NV                       = PIPELINE_STAGE_2_TASK_SHADER_BIT_EXT;
const PipelineStageFlags2 PIPELINE_STAGE_2_MESH_SHADER_BIT_NV                       = PIPELINE_STAGE_2_MESH_SHADER_BIT_EXT;
const PipelineStageFlags2 PIPELINE_STAGE_2_TASK_SHADER_BIT_EXT                      = 0x0000000000080000;
const PipelineStageFlags2 PIPELINE_STAGE_2_MESH_SHADER_BIT_EXT                      = 0x0000000000100000;
const PipelineStageFlags2 PIPELINE_STAGE_2_SUBPASS_SHADER_BIT_HUAWEI                = 0x0000008000000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_SUBPASS_SHADING_BIT_HUAWEI               = PIPELINE_STAGE_2_SUBPASS_SHADER_BIT_HUAWEI;
const PipelineStageFlags2 PIPELINE_STAGE_2_INVOCATION_MASK_BIT_HUAWEI               = 0x0000010000000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_ACCELERATION_STRUCTURE_COPY_BIT_KHR      = 0x0000000010000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_MICROMAP_BUILD_BIT_EXT                   = 0x0000000040000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_CLUSTER_CULLING_SHADER_BIT_HUAWEI        = 0x0000020000000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_OPTICAL_FLOW_BIT_NV                      = 0x0000000020000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_CONVERT_COOPERATIVE_VECTOR_MATRIX_BIT_NV = 0x0000100000000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_DATA_GRAPH_BIT_ARM                       = 0x0000040000000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_COPY_INDIRECT_BIT_KHR                    = 0x0000400000000000;
const PipelineStageFlags2 PIPELINE_STAGE_2_MEMORY_DECOMPRESSION_BIT_EXT             = 0x0000200000000000;

typedef AccelerationStructureMotionInfoFlagsNV @constinit = uint;

typedef AccelerationStructureMotionInstanceFlagsNV @constinit = uint;

alias FormatFeatureFlags2 = vulkan::vk::VkFormatFeatureFlags2;
alias FormatFeatureFlagBits2 = FormatFeatureFlags2;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_BIT                                                               = 0x0000000000000001;
const FormatFeatureFlags2 FORMAT_FEATURE_2_STORAGE_IMAGE_BIT                                                               = 0x0000000000000002;
const FormatFeatureFlags2 FORMAT_FEATURE_2_STORAGE_IMAGE_ATOMIC_BIT                                                        = 0x0000000000000004;
const FormatFeatureFlags2 FORMAT_FEATURE_2_UNIFORM_TEXEL_BUFFER_BIT                                                        = 0x0000000000000008;
const FormatFeatureFlags2 FORMAT_FEATURE_2_STORAGE_TEXEL_BUFFER_BIT                                                        = 0x0000000000000010;
const FormatFeatureFlags2 FORMAT_FEATURE_2_STORAGE_TEXEL_BUFFER_ATOMIC_BIT                                                 = 0x0000000000000020;
const FormatFeatureFlags2 FORMAT_FEATURE_2_VERTEX_BUFFER_BIT                                                               = 0x0000000000000040;
const FormatFeatureFlags2 FORMAT_FEATURE_2_COLOR_ATTACHMENT_BIT                                                            = 0x0000000000000080;
const FormatFeatureFlags2 FORMAT_FEATURE_2_COLOR_ATTACHMENT_BLEND_BIT                                                      = 0x0000000000000100;
const FormatFeatureFlags2 FORMAT_FEATURE_2_DEPTH_STENCIL_ATTACHMENT_BIT                                                    = 0x0000000000000200;
const FormatFeatureFlags2 FORMAT_FEATURE_2_BLIT_SRC_BIT                                                                    = 0x0000000000000400;
const FormatFeatureFlags2 FORMAT_FEATURE_2_BLIT_DST_BIT                                                                    = 0x0000000000000800;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_FILTER_LINEAR_BIT                                                 = 0x0000000000001000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_TRANSFER_SRC_BIT                                                                = 0x0000000000004000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_TRANSFER_DST_BIT                                                                = 0x0000000000008000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_FILTER_MINMAX_BIT                                                 = 0x0000000000010000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_MIDPOINT_CHROMA_SAMPLES_BIT                                                     = 0x0000000000020000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_YCBCR_CONVERSION_LINEAR_FILTER_BIT                                = 0x0000000000040000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_YCBCR_CONVERSION_SEPARATE_RECONSTRUCTION_FILTER_BIT               = 0x0000000000080000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_BIT               = 0x0000000000100000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_FORCEABLE_BIT     = 0x0000000000200000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_DISJOINT_BIT                                                                    = 0x0000000000400000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_COSITED_CHROMA_SAMPLES_BIT                                                      = 0x0000000000800000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_STORAGE_READ_WITHOUT_FORMAT_BIT                                                 = 0x0000000080000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_STORAGE_WRITE_WITHOUT_FORMAT_BIT                                                = 0x0000000100000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_DEPTH_COMPARISON_BIT                                              = 0x0000000200000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_FILTER_CUBIC_BIT                                                  = 0x0000000000002000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_HOST_IMAGE_TRANSFER_BIT                                                         = 0x0000400000000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_ACCELERATION_STRUCTURE_VERTEX_BUFFER_BIT_KHR                                    = 0x0000000020000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_FRAGMENT_DENSITY_MAP_BIT_EXT                                                    = 0x0000000001000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR                                        = 0x0000000040000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_HOST_IMAGE_TRANSFER_BIT_EXT                                                     = FORMAT_FEATURE_2_HOST_IMAGE_TRANSFER_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_BIT_KHR                                                           = FORMAT_FEATURE_2_SAMPLED_IMAGE_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_STORAGE_IMAGE_BIT_KHR                                                           = FORMAT_FEATURE_2_STORAGE_IMAGE_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_STORAGE_IMAGE_ATOMIC_BIT_KHR                                                    = FORMAT_FEATURE_2_STORAGE_IMAGE_ATOMIC_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_UNIFORM_TEXEL_BUFFER_BIT_KHR                                                    = FORMAT_FEATURE_2_UNIFORM_TEXEL_BUFFER_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_STORAGE_TEXEL_BUFFER_BIT_KHR                                                    = FORMAT_FEATURE_2_STORAGE_TEXEL_BUFFER_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_STORAGE_TEXEL_BUFFER_ATOMIC_BIT_KHR                                             = FORMAT_FEATURE_2_STORAGE_TEXEL_BUFFER_ATOMIC_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_VERTEX_BUFFER_BIT_KHR                                                           = FORMAT_FEATURE_2_VERTEX_BUFFER_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_COLOR_ATTACHMENT_BIT_KHR                                                        = FORMAT_FEATURE_2_COLOR_ATTACHMENT_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_COLOR_ATTACHMENT_BLEND_BIT_KHR                                                  = FORMAT_FEATURE_2_COLOR_ATTACHMENT_BLEND_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_DEPTH_STENCIL_ATTACHMENT_BIT_KHR                                                = FORMAT_FEATURE_2_DEPTH_STENCIL_ATTACHMENT_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_BLIT_SRC_BIT_KHR                                                                = FORMAT_FEATURE_2_BLIT_SRC_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_BLIT_DST_BIT_KHR                                                                = FORMAT_FEATURE_2_BLIT_DST_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_FILTER_LINEAR_BIT_KHR                                             = FORMAT_FEATURE_2_SAMPLED_IMAGE_FILTER_LINEAR_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_TRANSFER_SRC_BIT_KHR                                                            = FORMAT_FEATURE_2_TRANSFER_SRC_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_TRANSFER_DST_BIT_KHR                                                            = FORMAT_FEATURE_2_TRANSFER_DST_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_MIDPOINT_CHROMA_SAMPLES_BIT_KHR                                                 = FORMAT_FEATURE_2_MIDPOINT_CHROMA_SAMPLES_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_YCBCR_CONVERSION_LINEAR_FILTER_BIT_KHR                            = FORMAT_FEATURE_2_SAMPLED_IMAGE_YCBCR_CONVERSION_LINEAR_FILTER_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_YCBCR_CONVERSION_SEPARATE_RECONSTRUCTION_FILTER_BIT_KHR           = FORMAT_FEATURE_2_SAMPLED_IMAGE_YCBCR_CONVERSION_SEPARATE_RECONSTRUCTION_FILTER_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_BIT_KHR           = FORMAT_FEATURE_2_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_FORCEABLE_BIT_KHR = FORMAT_FEATURE_2_SAMPLED_IMAGE_YCBCR_CONVERSION_CHROMA_RECONSTRUCTION_EXPLICIT_FORCEABLE_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_DISJOINT_BIT_KHR                                                                = FORMAT_FEATURE_2_DISJOINT_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_COSITED_CHROMA_SAMPLES_BIT_KHR                                                  = FORMAT_FEATURE_2_COSITED_CHROMA_SAMPLES_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_STORAGE_READ_WITHOUT_FORMAT_BIT_KHR                                             = FORMAT_FEATURE_2_STORAGE_READ_WITHOUT_FORMAT_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_STORAGE_WRITE_WITHOUT_FORMAT_BIT_KHR                                            = FORMAT_FEATURE_2_STORAGE_WRITE_WITHOUT_FORMAT_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_DEPTH_COMPARISON_BIT_KHR                                          = FORMAT_FEATURE_2_SAMPLED_IMAGE_DEPTH_COMPARISON_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_FILTER_MINMAX_BIT_KHR                                             = FORMAT_FEATURE_2_SAMPLED_IMAGE_FILTER_MINMAX_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_SAMPLED_IMAGE_FILTER_CUBIC_BIT_EXT                                              = FORMAT_FEATURE_2_SAMPLED_IMAGE_FILTER_CUBIC_BIT;
const FormatFeatureFlags2 FORMAT_FEATURE_2_ACCELERATION_STRUCTURE_RADIUS_BUFFER_BIT_NV                                     = 0x0008000000000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_LINEAR_COLOR_ATTACHMENT_BIT_NV                                                  = 0x0000004000000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_WEIGHT_IMAGE_BIT_QCOM                                                           = 0x0000000400000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_WEIGHT_SAMPLED_IMAGE_BIT_QCOM                                                   = 0x0000000800000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_BLOCK_MATCHING_BIT_QCOM                                                         = 0x0000001000000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_BOX_FILTER_SAMPLED_BIT_QCOM                                                     = 0x0000002000000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_TENSOR_SHADER_BIT_ARM                                                           = 0x0000008000000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_TENSOR_IMAGE_ALIASING_BIT_ARM                                                   = 0x0000080000000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_OPTICAL_FLOW_IMAGE_BIT_NV                                                       = 0x0000010000000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_OPTICAL_FLOW_VECTOR_BIT_NV                                                      = 0x0000020000000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_OPTICAL_FLOW_COST_BIT_NV                                                        = 0x0000040000000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_TENSOR_DATA_GRAPH_BIT_ARM                                                       = 0x0001000000000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_COPY_IMAGE_INDIRECT_DST_BIT_KHR                                                 = 0x0800000000000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_DEPTH_COPY_ON_COMPUTE_QUEUE_BIT_KHR                                             = 0x0010000000000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_DEPTH_COPY_ON_TRANSFER_QUEUE_BIT_KHR                                            = 0x0020000000000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_STENCIL_COPY_ON_COMPUTE_QUEUE_BIT_KHR                                           = 0x0040000000000000;
const FormatFeatureFlags2 FORMAT_FEATURE_2_STENCIL_COPY_ON_TRANSFER_QUEUE_BIT_KHR                                          = 0x0080000000000000;

alias RenderingFlags = vulkan::vk::VkRenderingFlags;
alias RenderingFlagBits = RenderingFlags;
const RenderingFlags RENDERING_CONTENTS_SECONDARY_COMMAND_BUFFERS_BIT       = 0x00000001;
const RenderingFlags RENDERING_SUSPENDING_BIT                               = 0x00000002;
const RenderingFlags RENDERING_RESUMING_BIT                                 = 0x00000004;
const RenderingFlags RENDERING_CONTENTS_SECONDARY_COMMAND_BUFFERS_BIT_KHR   = RENDERING_CONTENTS_SECONDARY_COMMAND_BUFFERS_BIT;
const RenderingFlags RENDERING_SUSPENDING_BIT_KHR                           = RENDERING_SUSPENDING_BIT;
const RenderingFlags RENDERING_RESUMING_BIT_KHR                             = RENDERING_RESUMING_BIT;
const RenderingFlags RENDERING_CONTENTS_INLINE_BIT_EXT                      = RENDERING_CONTENTS_INLINE_BIT_KHR;
const RenderingFlags RENDERING_ENABLE_LEGACY_DITHERING_BIT_EXT              = 0x00000008;
const RenderingFlags RENDERING_CONTENTS_INLINE_BIT_KHR                      = 0x00000010;
const RenderingFlags RENDERING_PER_LAYER_FRAGMENT_DENSITY_BIT_VALVE         = 0x00000020;
const RenderingFlags RENDERING_FRAGMENT_REGION_BIT_EXT                      = 0x00000040;
const RenderingFlags RENDERING_CUSTOM_RESOLVE_BIT_EXT                       = 0x00000080;
const RenderingFlags RENDERING_LOCAL_READ_CONCURRENT_ACCESS_CONTROL_BIT_KHR = 0x00000100;

typedef MemoryDecompressionMethodFlagsEXT @constinit = ulong;
alias MemoryDecompressionMethodFlagBitsEXT = MemoryDecompressionMethodFlagsEXT;
const MemoryDecompressionMethodFlagsEXT MEMORY_DECOMPRESSION_METHOD_GDEFLATE_1_0_BIT_EXT = 0x0000000000000001;
const MemoryDecompressionMethodFlagsEXT MEMORY_DECOMPRESSION_METHOD_GDEFLATE_1_0_BIT_NV  = MEMORY_DECOMPRESSION_METHOD_GDEFLATE_1_0_BIT_EXT;

typedef BuildMicromapFlagsEXT @constinit = uint;
alias BuildMicromapFlagBitsEXT = BuildMicromapFlagsEXT;
const BuildMicromapFlagsEXT BUILD_MICROMAP_PREFER_FAST_TRACE_BIT_EXT = 0x00000001;
const BuildMicromapFlagsEXT BUILD_MICROMAP_PREFER_FAST_BUILD_BIT_EXT = 0x00000002;
const BuildMicromapFlagsEXT BUILD_MICROMAP_ALLOW_COMPACTION_BIT_EXT  = 0x00000004;

typedef MicromapCreateFlagsEXT @constinit = uint;
alias MicromapCreateFlagBitsEXT = MicromapCreateFlagsEXT;
const MicromapCreateFlagsEXT MICROMAP_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT_EXT = 0x00000001;

typedef IndirectCommandsLayoutUsageFlagsEXT @constinit = uint;
alias IndirectCommandsLayoutUsageFlagBitsEXT = IndirectCommandsLayoutUsageFlagsEXT;
const IndirectCommandsLayoutUsageFlagsEXT INDIRECT_COMMANDS_LAYOUT_USAGE_EXPLICIT_PREPROCESS_BIT_EXT = 0x00000001;
const IndirectCommandsLayoutUsageFlagsEXT INDIRECT_COMMANDS_LAYOUT_USAGE_UNORDERED_SEQUENCES_BIT_EXT = 0x00000002;

typedef IndirectCommandsInputModeFlagsEXT @constinit = uint;
alias IndirectCommandsInputModeFlagBitsEXT = IndirectCommandsInputModeFlagsEXT;
const IndirectCommandsInputModeFlagsEXT INDIRECT_COMMANDS_INPUT_MODE_VULKAN_INDEX_BUFFER_EXT = 0x00000001;
const IndirectCommandsInputModeFlagsEXT INDIRECT_COMMANDS_INPUT_MODE_DXGI_INDEX_BUFFER_EXT   = 0x00000002;

typedef DirectDriverLoadingFlagsLUNARG @constinit = uint;

typedef PipelineCreateFlags2 @constinit = ulong;
alias PipelineCreateFlagBits2 = PipelineCreateFlags2;
const PipelineCreateFlags2 PIPELINE_CREATE_2_DISABLE_OPTIMIZATION_BIT                                  = 0x0000000000000001;
const PipelineCreateFlags2 PIPELINE_CREATE_2_ALLOW_DERIVATIVES_BIT                                     = 0x0000000000000002;
const PipelineCreateFlags2 PIPELINE_CREATE_2_DERIVATIVE_BIT                                            = 0x0000000000000004;
const PipelineCreateFlags2 PIPELINE_CREATE_2_VIEW_INDEX_FROM_DEVICE_INDEX_BIT                          = 0x0000000000000008;
const PipelineCreateFlags2 PIPELINE_CREATE_2_DISPATCH_BASE_BIT                                         = 0x0000000000000010;
const PipelineCreateFlags2 PIPELINE_CREATE_2_FAIL_ON_PIPELINE_COMPILE_REQUIRED_BIT                     = 0x0000000000000100;
const PipelineCreateFlags2 PIPELINE_CREATE_2_EARLY_RETURN_ON_FAILURE_BIT                               = 0x0000000000000200;
const PipelineCreateFlags2 PIPELINE_CREATE_2_NO_PROTECTED_ACCESS_BIT                                   = 0x0000000008000000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_PROTECTED_ACCESS_ONLY_BIT                                 = 0x0000000040000000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_DESCRIPTOR_HEAP_BIT_EXT                                   = 0x0000001000000000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_RAY_TRACING_SKIP_BUILT_IN_PRIMITIVES_BIT_KHR              = PIPELINE_CREATE_2_RAY_TRACING_SKIP_TRIANGLES_BIT_KHR;
const PipelineCreateFlags2 PIPELINE_CREATE_2_RAY_TRACING_ALLOW_SPHERES_AND_LINEAR_SWEPT_SPHERES_BIT_NV = 0x0000000200000000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_ENABLE_LEGACY_DITHERING_BIT_EXT                           = 0x0000000400000000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_DISABLE_OPTIMIZATION_BIT_KHR                              = PIPELINE_CREATE_2_DISABLE_OPTIMIZATION_BIT;
const PipelineCreateFlags2 PIPELINE_CREATE_2_ALLOW_DERIVATIVES_BIT_KHR                                 = PIPELINE_CREATE_2_ALLOW_DERIVATIVES_BIT;
const PipelineCreateFlags2 PIPELINE_CREATE_2_DERIVATIVE_BIT_KHR                                        = PIPELINE_CREATE_2_DERIVATIVE_BIT;
const PipelineCreateFlags2 PIPELINE_CREATE_2_VIEW_INDEX_FROM_DEVICE_INDEX_BIT_KHR                      = PIPELINE_CREATE_2_VIEW_INDEX_FROM_DEVICE_INDEX_BIT;
const PipelineCreateFlags2 PIPELINE_CREATE_2_DISPATCH_BASE_BIT_KHR                                     = PIPELINE_CREATE_2_DISPATCH_BASE_BIT;
const PipelineCreateFlags2 PIPELINE_CREATE_2_DEFER_COMPILE_BIT_NV                                      = 0x0000000000000020;
const PipelineCreateFlags2 PIPELINE_CREATE_2_CAPTURE_STATISTICS_BIT_KHR                                = 0x0000000000000040;
const PipelineCreateFlags2 PIPELINE_CREATE_2_CAPTURE_INTERNAL_REPRESENTATIONS_BIT_KHR                  = 0x0000000000000080;
const PipelineCreateFlags2 PIPELINE_CREATE_2_FAIL_ON_PIPELINE_COMPILE_REQUIRED_BIT_KHR                 = PIPELINE_CREATE_2_FAIL_ON_PIPELINE_COMPILE_REQUIRED_BIT;
const PipelineCreateFlags2 PIPELINE_CREATE_2_EARLY_RETURN_ON_FAILURE_BIT_KHR                           = PIPELINE_CREATE_2_EARLY_RETURN_ON_FAILURE_BIT;
const PipelineCreateFlags2 PIPELINE_CREATE_2_LINK_TIME_OPTIMIZATION_BIT_EXT                            = 0x0000000000000400;
const PipelineCreateFlags2 PIPELINE_CREATE_2_RETAIN_LINK_TIME_OPTIMIZATION_INFO_BIT_EXT                = 0x0000000000800000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_LIBRARY_BIT_KHR                                           = 0x0000000000000800;
const PipelineCreateFlags2 PIPELINE_CREATE_2_RAY_TRACING_SKIP_TRIANGLES_BIT_KHR                        = 0x0000000000001000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_RAY_TRACING_SKIP_AABBS_BIT_KHR                            = 0x0000000000002000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_RAY_TRACING_NO_NULL_ANY_HIT_SHADERS_BIT_KHR               = 0x0000000000004000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_RAY_TRACING_NO_NULL_CLOSEST_HIT_SHADERS_BIT_KHR           = 0x0000000000008000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_RAY_TRACING_NO_NULL_MISS_SHADERS_BIT_KHR                  = 0x0000000000010000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_RAY_TRACING_NO_NULL_INTERSECTION_SHADERS_BIT_KHR          = 0x0000000000020000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_RAY_TRACING_SHADER_GROUP_HANDLE_CAPTURE_REPLAY_BIT_KHR    = 0x0000000000080000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_INDIRECT_BINDABLE_BIT_NV                                  = 0x0000000000040000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_RAY_TRACING_ALLOW_MOTION_BIT_NV                           = 0x0000000000100000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_RENDERING_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR        = 0x0000000000200000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_RENDERING_FRAGMENT_DENSITY_MAP_ATTACHMENT_BIT_EXT         = 0x0000000000400000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_RAY_TRACING_OPACITY_MICROMAP_BIT_EXT                      = 0x0000000001000000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_COLOR_ATTACHMENT_FEEDBACK_LOOP_BIT_EXT                    = 0x0000000002000000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_DEPTH_STENCIL_ATTACHMENT_FEEDBACK_LOOP_BIT_EXT            = 0x0000000004000000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_NO_PROTECTED_ACCESS_BIT_EXT                               = PIPELINE_CREATE_2_NO_PROTECTED_ACCESS_BIT;
const PipelineCreateFlags2 PIPELINE_CREATE_2_PROTECTED_ACCESS_ONLY_BIT_EXT                             = PIPELINE_CREATE_2_PROTECTED_ACCESS_ONLY_BIT;
const PipelineCreateFlags2 PIPELINE_CREATE_2_DESCRIPTOR_BUFFER_BIT_EXT                                 = 0x0000000020000000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_DISALLOW_OPACITY_MICROMAP_BIT_ARM                         = 0x0000002000000000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_CAPTURE_DATA_BIT_KHR                                      = 0x0000000080000000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_INDIRECT_BINDABLE_BIT_EXT                                 = 0x0000004000000000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_PER_LAYER_FRAGMENT_DENSITY_BIT_VALVE                      = 0x0000010000000000;
const PipelineCreateFlags2 PIPELINE_CREATE_2_64_BIT_INDEXING_BIT_EXT                                   = 0x0000080000000000;

typedef BufferUsageFlags2 @constinit = ulong;
alias BufferUsageFlagBits2 = BufferUsageFlags2;
const BufferUsageFlags2 BUFFER_USAGE_2_TRANSFER_SRC_BIT                                     = 0x0000000000000001;
const BufferUsageFlags2 BUFFER_USAGE_2_TRANSFER_DST_BIT                                     = 0x0000000000000002;
const BufferUsageFlags2 BUFFER_USAGE_2_UNIFORM_TEXEL_BUFFER_BIT                             = 0x0000000000000004;
const BufferUsageFlags2 BUFFER_USAGE_2_STORAGE_TEXEL_BUFFER_BIT                             = 0x0000000000000008;
const BufferUsageFlags2 BUFFER_USAGE_2_UNIFORM_BUFFER_BIT                                   = 0x0000000000000010;
const BufferUsageFlags2 BUFFER_USAGE_2_STORAGE_BUFFER_BIT                                   = 0x0000000000000020;
const BufferUsageFlags2 BUFFER_USAGE_2_INDEX_BUFFER_BIT                                     = 0x0000000000000040;
const BufferUsageFlags2 BUFFER_USAGE_2_VERTEX_BUFFER_BIT                                    = 0x0000000000000080;
const BufferUsageFlags2 BUFFER_USAGE_2_INDIRECT_BUFFER_BIT                                  = 0x0000000000000100;
const BufferUsageFlags2 BUFFER_USAGE_2_SHADER_DEVICE_ADDRESS_BIT                            = 0x0000000000020000;
const BufferUsageFlags2 BUFFER_USAGE_2_DESCRIPTOR_HEAP_BIT_EXT                              = 0x0000000010000000;
const BufferUsageFlags2 BUFFER_USAGE_2_TRANSFER_SRC_BIT_KHR                                 = BUFFER_USAGE_2_TRANSFER_SRC_BIT;
const BufferUsageFlags2 BUFFER_USAGE_2_TRANSFER_DST_BIT_KHR                                 = BUFFER_USAGE_2_TRANSFER_DST_BIT;
const BufferUsageFlags2 BUFFER_USAGE_2_UNIFORM_TEXEL_BUFFER_BIT_KHR                         = BUFFER_USAGE_2_UNIFORM_TEXEL_BUFFER_BIT;
const BufferUsageFlags2 BUFFER_USAGE_2_STORAGE_TEXEL_BUFFER_BIT_KHR                         = BUFFER_USAGE_2_STORAGE_TEXEL_BUFFER_BIT;
const BufferUsageFlags2 BUFFER_USAGE_2_UNIFORM_BUFFER_BIT_KHR                               = BUFFER_USAGE_2_UNIFORM_BUFFER_BIT;
const BufferUsageFlags2 BUFFER_USAGE_2_STORAGE_BUFFER_BIT_KHR                               = BUFFER_USAGE_2_STORAGE_BUFFER_BIT;
const BufferUsageFlags2 BUFFER_USAGE_2_INDEX_BUFFER_BIT_KHR                                 = BUFFER_USAGE_2_INDEX_BUFFER_BIT;
const BufferUsageFlags2 BUFFER_USAGE_2_VERTEX_BUFFER_BIT_KHR                                = BUFFER_USAGE_2_VERTEX_BUFFER_BIT;
const BufferUsageFlags2 BUFFER_USAGE_2_INDIRECT_BUFFER_BIT_KHR                              = BUFFER_USAGE_2_INDIRECT_BUFFER_BIT;
const BufferUsageFlags2 BUFFER_USAGE_2_CONDITIONAL_RENDERING_BIT_EXT                        = 0x0000000000000200;
const BufferUsageFlags2 BUFFER_USAGE_2_SHADER_BINDING_TABLE_BIT_KHR                         = 0x0000000000000400;
const BufferUsageFlags2 BUFFER_USAGE_2_RAY_TRACING_BIT_NV                                   = BUFFER_USAGE_2_SHADER_BINDING_TABLE_BIT_KHR;
const BufferUsageFlags2 BUFFER_USAGE_2_TRANSFORM_FEEDBACK_BUFFER_BIT_EXT                    = 0x0000000000000800;
const BufferUsageFlags2 BUFFER_USAGE_2_TRANSFORM_FEEDBACK_COUNTER_BUFFER_BIT_EXT            = 0x0000000000001000;
const BufferUsageFlags2 BUFFER_USAGE_2_SHADER_DEVICE_ADDRESS_BIT_KHR                        = BUFFER_USAGE_2_SHADER_DEVICE_ADDRESS_BIT;
const BufferUsageFlags2 BUFFER_USAGE_2_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR = 0x0000000000080000;
const BufferUsageFlags2 BUFFER_USAGE_2_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR               = 0x0000000000100000;
const BufferUsageFlags2 BUFFER_USAGE_2_SAMPLER_DESCRIPTOR_BUFFER_BIT_EXT                    = 0x0000000000200000;
const BufferUsageFlags2 BUFFER_USAGE_2_RESOURCE_DESCRIPTOR_BUFFER_BIT_EXT                   = 0x0000000000400000;
const BufferUsageFlags2 BUFFER_USAGE_2_PUSH_DESCRIPTORS_DESCRIPTOR_BUFFER_BIT_EXT           = 0x0000000004000000;
const BufferUsageFlags2 BUFFER_USAGE_2_MICROMAP_BUILD_INPUT_READ_ONLY_BIT_EXT               = 0x0000000000800000;
const BufferUsageFlags2 BUFFER_USAGE_2_MICROMAP_STORAGE_BIT_EXT                             = 0x0000000001000000;
const BufferUsageFlags2 BUFFER_USAGE_2_DATA_GRAPH_FOREIGN_DESCRIPTOR_BIT_ARM                = 0x0000000020000000;
const BufferUsageFlags2 BUFFER_USAGE_2_TILE_MEMORY_BIT_QCOM                                 = 0x0000000008000000;
const BufferUsageFlags2 BUFFER_USAGE_2_MEMORY_DECOMPRESSION_BIT_EXT                         = 0x0000000100000000;
const BufferUsageFlags2 BUFFER_USAGE_2_PREPROCESS_BUFFER_BIT_EXT                            = 0x0000000080000000;

typedef AddressCopyFlagsKHR @constinit = uint;
alias AddressCopyFlagBitsKHR = AddressCopyFlagsKHR;
const AddressCopyFlagsKHR ADDRESS_COPY_DEVICE_LOCAL_BIT_KHR = 0x00000001;
const AddressCopyFlagsKHR ADDRESS_COPY_SPARSE_BIT_KHR       = 0x00000002;
const AddressCopyFlagsKHR ADDRESS_COPY_PROTECTED_BIT_KHR    = 0x00000004;

typedef TensorCreateFlagsARM @constinit = ulong;
alias TensorCreateFlagBitsARM = TensorCreateFlagsARM;
const TensorCreateFlagsARM TENSOR_CREATE_MUTABLE_FORMAT_BIT_ARM                   = 0x0000000000000001;
const TensorCreateFlagsARM TENSOR_CREATE_PROTECTED_BIT_ARM                        = 0x0000000000000002;
const TensorCreateFlagsARM TENSOR_CREATE_DESCRIPTOR_HEAP_CAPTURE_REPLAY_BIT_ARM   = 0x0000000000000008;
const TensorCreateFlagsARM TENSOR_CREATE_DESCRIPTOR_BUFFER_CAPTURE_REPLAY_BIT_ARM = 0x0000000000000004;

typedef TensorUsageFlagsARM @constinit = ulong;
alias TensorUsageFlagBitsARM = TensorUsageFlagsARM;
const TensorUsageFlagsARM TENSOR_USAGE_SHADER_BIT_ARM         = 0x0000000000000002;
const TensorUsageFlagsARM TENSOR_USAGE_TRANSFER_SRC_BIT_ARM   = 0x0000000000000004;
const TensorUsageFlagsARM TENSOR_USAGE_TRANSFER_DST_BIT_ARM   = 0x0000000000000008;
const TensorUsageFlagsARM TENSOR_USAGE_IMAGE_ALIASING_BIT_ARM = 0x0000000000000010;
const TensorUsageFlagsARM TENSOR_USAGE_DATA_GRAPH_BIT_ARM     = 0x0000000000000020;

typedef TensorViewCreateFlagsARM @constinit = ulong;
alias TensorViewCreateFlagBitsARM = TensorViewCreateFlagsARM;
const TensorViewCreateFlagsARM TENSOR_VIEW_CREATE_DESCRIPTOR_BUFFER_CAPTURE_REPLAY_BIT_ARM = 0x0000000000000001;

typedef DataGraphPipelineSessionCreateFlagsARM @constinit = ulong;
alias DataGraphPipelineSessionCreateFlagBitsARM = DataGraphPipelineSessionCreateFlagsARM;
const DataGraphPipelineSessionCreateFlagsARM DATA_GRAPH_PIPELINE_SESSION_CREATE_PROTECTED_BIT_ARM = 0x0000000000000001;

typedef DataGraphPipelineDispatchFlagsARM @constinit = ulong;
alias DataGraphPipelineDispatchFlagBitsARM = DataGraphPipelineDispatchFlagsARM;

typedef SpirvResourceTypeFlagsEXT @constinit = uint;
alias SpirvResourceTypeFlagBitsEXT = SpirvResourceTypeFlagsEXT;
const SpirvResourceTypeFlagsEXT SPIRV_RESOURCE_TYPE_ALL_EXT                           = 0x7FFFFFFF;
const SpirvResourceTypeFlagsEXT SPIRV_RESOURCE_TYPE_SAMPLER_BIT_EXT                   = 0x00000001;
const SpirvResourceTypeFlagsEXT SPIRV_RESOURCE_TYPE_SAMPLED_IMAGE_BIT_EXT             = 0x00000002;
const SpirvResourceTypeFlagsEXT SPIRV_RESOURCE_TYPE_READ_ONLY_IMAGE_BIT_EXT           = 0x00000004;
const SpirvResourceTypeFlagsEXT SPIRV_RESOURCE_TYPE_READ_WRITE_IMAGE_BIT_EXT          = 0x00000008;
const SpirvResourceTypeFlagsEXT SPIRV_RESOURCE_TYPE_COMBINED_SAMPLED_IMAGE_BIT_EXT    = 0x00000010;
const SpirvResourceTypeFlagsEXT SPIRV_RESOURCE_TYPE_UNIFORM_BUFFER_BIT_EXT            = 0x00000020;
const SpirvResourceTypeFlagsEXT SPIRV_RESOURCE_TYPE_READ_ONLY_STORAGE_BUFFER_BIT_EXT  = 0x00000040;
const SpirvResourceTypeFlagsEXT SPIRV_RESOURCE_TYPE_READ_WRITE_STORAGE_BUFFER_BIT_EXT = 0x00000080;
const SpirvResourceTypeFlagsEXT SPIRV_RESOURCE_TYPE_ACCELERATION_STRUCTURE_BIT_EXT    = 0x00000100;
const SpirvResourceTypeFlagsEXT SPIRV_RESOURCE_TYPE_TENSOR_BIT_ARM                    = 0x00000200;

typedef CompositeAlphaFlagsKHR @constinit = uint;
alias CompositeAlphaFlagBitsKHR = CompositeAlphaFlagsKHR;
const CompositeAlphaFlagsKHR COMPOSITE_ALPHA_OPAQUE_BIT_KHR          = 0x00000001;
const CompositeAlphaFlagsKHR COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR  = 0x00000002;
const CompositeAlphaFlagsKHR COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR = 0x00000004;
const CompositeAlphaFlagsKHR COMPOSITE_ALPHA_INHERIT_BIT_KHR         = 0x00000008;

typedef DisplayPlaneAlphaFlagsKHR @constinit = uint;
alias DisplayPlaneAlphaFlagBitsKHR = DisplayPlaneAlphaFlagsKHR;
const DisplayPlaneAlphaFlagsKHR DISPLAY_PLANE_ALPHA_OPAQUE_BIT_KHR                  = 0x00000001;
const DisplayPlaneAlphaFlagsKHR DISPLAY_PLANE_ALPHA_GLOBAL_BIT_KHR                  = 0x00000002;
const DisplayPlaneAlphaFlagsKHR DISPLAY_PLANE_ALPHA_PER_PIXEL_BIT_KHR               = 0x00000004;
const DisplayPlaneAlphaFlagsKHR DISPLAY_PLANE_ALPHA_PER_PIXEL_PREMULTIPLIED_BIT_KHR = 0x00000008;

typedef SurfaceTransformFlagsKHR @constinit = uint;
alias SurfaceTransformFlagBitsKHR = SurfaceTransformFlagsKHR;
const SurfaceTransformFlagsKHR SURFACE_TRANSFORM_IDENTITY_BIT_KHR                     = 0x00000001;
const SurfaceTransformFlagsKHR SURFACE_TRANSFORM_ROTATE_90_BIT_KHR                    = 0x00000002;
const SurfaceTransformFlagsKHR SURFACE_TRANSFORM_ROTATE_180_BIT_KHR                   = 0x00000004;
const SurfaceTransformFlagsKHR SURFACE_TRANSFORM_ROTATE_270_BIT_KHR                   = 0x00000008;
const SurfaceTransformFlagsKHR SURFACE_TRANSFORM_HORIZONTAL_MIRROR_BIT_KHR            = 0x00000010;
const SurfaceTransformFlagsKHR SURFACE_TRANSFORM_HORIZONTAL_MIRROR_ROTATE_90_BIT_KHR  = 0x00000020;
const SurfaceTransformFlagsKHR SURFACE_TRANSFORM_HORIZONTAL_MIRROR_ROTATE_180_BIT_KHR = 0x00000040;
const SurfaceTransformFlagsKHR SURFACE_TRANSFORM_HORIZONTAL_MIRROR_ROTATE_270_BIT_KHR = 0x00000080;
const SurfaceTransformFlagsKHR SURFACE_TRANSFORM_INHERIT_BIT_KHR                      = 0x00000100;

typedef SwapchainCreateFlagsKHR @constinit = uint;
alias SwapchainCreateFlagBitsKHR = SwapchainCreateFlagsKHR;
const SwapchainCreateFlagsKHR SWAPCHAIN_CREATE_SPLIT_INSTANCE_BIND_REGIONS_BIT_KHR = 0x00000001;
const SwapchainCreateFlagsKHR SWAPCHAIN_CREATE_PROTECTED_BIT_KHR                   = 0x00000002;
const SwapchainCreateFlagsKHR SWAPCHAIN_CREATE_MUTABLE_FORMAT_BIT_KHR              = 0x00000004;
const SwapchainCreateFlagsKHR SWAPCHAIN_CREATE_PRESENT_TIMING_BIT_EXT              = 0x00000200;
const SwapchainCreateFlagsKHR SWAPCHAIN_CREATE_DEFERRED_MEMORY_ALLOCATION_BIT_EXT  = SWAPCHAIN_CREATE_DEFERRED_MEMORY_ALLOCATION_BIT_KHR;
const SwapchainCreateFlagsKHR SWAPCHAIN_CREATE_PRESENT_ID_2_BIT_KHR                = 0x00000040;
const SwapchainCreateFlagsKHR SWAPCHAIN_CREATE_PRESENT_WAIT_2_BIT_KHR              = 0x00000080;
const SwapchainCreateFlagsKHR SWAPCHAIN_CREATE_DEFERRED_MEMORY_ALLOCATION_BIT_KHR  = 0x00000008;

typedef DisplayModeCreateFlagsKHR @constinit = uint;

typedef DisplaySurfaceCreateFlagsKHR @constinit = uint;

typedef WaylandSurfaceCreateFlagsKHR @constinit = uint;

typedef Win32SurfaceCreateFlagsKHR @constinit = uint;

typedef XlibSurfaceCreateFlagsKHR @constinit = uint;

typedef HeadlessSurfaceCreateFlagsEXT @constinit = uint;

alias PeerMemoryFeatureFlags = vulkan::vk::VkPeerMemoryFeatureFlags;
alias PeerMemoryFeatureFlagBits = PeerMemoryFeatureFlags;
const PeerMemoryFeatureFlags PEER_MEMORY_FEATURE_COPY_SRC_BIT        = 0x00000001;
const PeerMemoryFeatureFlags PEER_MEMORY_FEATURE_COPY_DST_BIT        = 0x00000002;
const PeerMemoryFeatureFlags PEER_MEMORY_FEATURE_GENERIC_SRC_BIT     = 0x00000004;
const PeerMemoryFeatureFlags PEER_MEMORY_FEATURE_GENERIC_DST_BIT     = 0x00000008;
const PeerMemoryFeatureFlags PEER_MEMORY_FEATURE_COPY_SRC_BIT_KHR    = PEER_MEMORY_FEATURE_COPY_SRC_BIT;
const PeerMemoryFeatureFlags PEER_MEMORY_FEATURE_COPY_DST_BIT_KHR    = PEER_MEMORY_FEATURE_COPY_DST_BIT;
const PeerMemoryFeatureFlags PEER_MEMORY_FEATURE_GENERIC_SRC_BIT_KHR = PEER_MEMORY_FEATURE_GENERIC_SRC_BIT;
const PeerMemoryFeatureFlags PEER_MEMORY_FEATURE_GENERIC_DST_BIT_KHR = PEER_MEMORY_FEATURE_GENERIC_DST_BIT;

alias MemoryAllocateFlags = vulkan::vk::VkMemoryAllocateFlags;
alias MemoryAllocateFlagBits = MemoryAllocateFlags;
const MemoryAllocateFlags MEMORY_ALLOCATE_DEVICE_MASK_BIT                       = 0x00000001;
const MemoryAllocateFlags MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT                    = 0x00000002;
const MemoryAllocateFlags MEMORY_ALLOCATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT     = 0x00000004;
const MemoryAllocateFlags MEMORY_ALLOCATE_DEVICE_MASK_BIT_KHR                   = MEMORY_ALLOCATE_DEVICE_MASK_BIT;
const MemoryAllocateFlags MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT_KHR                = MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;
const MemoryAllocateFlags MEMORY_ALLOCATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT_KHR = MEMORY_ALLOCATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT;
const MemoryAllocateFlags MEMORY_ALLOCATE_ZERO_INITIALIZE_BIT_EXT               = 0x00000008;

typedef DeviceGroupPresentModeFlagsKHR @constinit = uint;
alias DeviceGroupPresentModeFlagBitsKHR = DeviceGroupPresentModeFlagsKHR;
const DeviceGroupPresentModeFlagsKHR DEVICE_GROUP_PRESENT_MODE_LOCAL_BIT_KHR              = 0x00000001;
const DeviceGroupPresentModeFlagsKHR DEVICE_GROUP_PRESENT_MODE_REMOTE_BIT_KHR             = 0x00000002;
const DeviceGroupPresentModeFlagsKHR DEVICE_GROUP_PRESENT_MODE_SUM_BIT_KHR                = 0x00000004;
const DeviceGroupPresentModeFlagsKHR DEVICE_GROUP_PRESENT_MODE_LOCAL_MULTI_DEVICE_BIT_KHR = 0x00000008;

typedef DebugReportFlagsEXT @constinit = uint;
alias DebugReportFlagBitsEXT = DebugReportFlagsEXT;
const DebugReportFlagsEXT DEBUG_REPORT_INFORMATION_BIT_EXT         = 0x00000001;
const DebugReportFlagsEXT DEBUG_REPORT_WARNING_BIT_EXT             = 0x00000002;
const DebugReportFlagsEXT DEBUG_REPORT_PERFORMANCE_WARNING_BIT_EXT = 0x00000004;
const DebugReportFlagsEXT DEBUG_REPORT_ERROR_BIT_EXT               = 0x00000008;
const DebugReportFlagsEXT DEBUG_REPORT_DEBUG_BIT_EXT               = 0x00000010;

alias CommandPoolTrimFlags = vulkan::vk::VkCommandPoolTrimFlags;

typedef ExternalMemoryHandleTypeFlagsNV @constinit = uint;
alias ExternalMemoryHandleTypeFlagBitsNV = ExternalMemoryHandleTypeFlagsNV;
const ExternalMemoryHandleTypeFlagsNV EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_BIT_NV     = 0x00000001;
const ExternalMemoryHandleTypeFlagsNV EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_KMT_BIT_NV = 0x00000002;
const ExternalMemoryHandleTypeFlagsNV EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_IMAGE_BIT_NV      = 0x00000004;
const ExternalMemoryHandleTypeFlagsNV EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_IMAGE_KMT_BIT_NV  = 0x00000008;

typedef ClusterAccelerationStructureIndexFormatFlagsNV @constinit = uint;
alias ClusterAccelerationStructureIndexFormatFlagBitsNV = ClusterAccelerationStructureIndexFormatFlagsNV;
const ClusterAccelerationStructureIndexFormatFlagsNV CLUSTER_ACCELERATION_STRUCTURE_INDEX_FORMAT_8BIT_NV  = 0x00000001;
const ClusterAccelerationStructureIndexFormatFlagsNV CLUSTER_ACCELERATION_STRUCTURE_INDEX_FORMAT_16BIT_NV = 0x00000002;
const ClusterAccelerationStructureIndexFormatFlagsNV CLUSTER_ACCELERATION_STRUCTURE_INDEX_FORMAT_32BIT_NV = 0x00000004;

typedef ExternalMemoryFeatureFlagsNV @constinit = uint;
alias ExternalMemoryFeatureFlagBitsNV = ExternalMemoryFeatureFlagsNV;
const ExternalMemoryFeatureFlagsNV EXTERNAL_MEMORY_FEATURE_DEDICATED_ONLY_BIT_NV = 0x00000001;
const ExternalMemoryFeatureFlagsNV EXTERNAL_MEMORY_FEATURE_EXPORTABLE_BIT_NV     = 0x00000002;
const ExternalMemoryFeatureFlagsNV EXTERNAL_MEMORY_FEATURE_IMPORTABLE_BIT_NV     = 0x00000004;

alias ExternalMemoryHandleTypeFlags = vulkan::vk::VkExternalMemoryHandleTypeFlags;
alias ExternalMemoryHandleTypeFlagBits = ExternalMemoryHandleTypeFlags;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_FD_BIT                      = 0x00000001;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_BIT                   = 0x00000002;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_KMT_BIT               = 0x00000004;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_BIT                  = 0x00000008;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_KMT_BIT              = 0x00000010;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_D3D12_HEAP_BIT                     = 0x00000020;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_D3D12_RESOURCE_BIT                 = 0x00000040;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_FD_BIT_KHR                  = EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_FD_BIT;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_BIT_KHR               = EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_BIT;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_KMT_BIT_KHR           = EXTERNAL_MEMORY_HANDLE_TYPE_OPAQUE_WIN32_KMT_BIT;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_BIT_KHR              = EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_BIT;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_KMT_BIT_KHR          = EXTERNAL_MEMORY_HANDLE_TYPE_D3D11_TEXTURE_KMT_BIT;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_D3D12_HEAP_BIT_KHR                 = EXTERNAL_MEMORY_HANDLE_TYPE_D3D12_HEAP_BIT;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_D3D12_RESOURCE_BIT_KHR             = EXTERNAL_MEMORY_HANDLE_TYPE_D3D12_RESOURCE_BIT;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT                    = 0x00000200;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_HOST_ALLOCATION_BIT_EXT            = 0x00000080;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_HOST_MAPPED_FOREIGN_MEMORY_BIT_EXT = 0x00000100;
const ExternalMemoryHandleTypeFlags EXTERNAL_MEMORY_HANDLE_TYPE_RDMA_ADDRESS_BIT_NV                = 0x00001000;

alias ExternalMemoryFeatureFlags = vulkan::vk::VkExternalMemoryFeatureFlags;
alias ExternalMemoryFeatureFlagBits = ExternalMemoryFeatureFlags;
const ExternalMemoryFeatureFlags EXTERNAL_MEMORY_FEATURE_DEDICATED_ONLY_BIT     = 0x00000001;
const ExternalMemoryFeatureFlags EXTERNAL_MEMORY_FEATURE_EXPORTABLE_BIT         = 0x00000002;
const ExternalMemoryFeatureFlags EXTERNAL_MEMORY_FEATURE_IMPORTABLE_BIT         = 0x00000004;
const ExternalMemoryFeatureFlags EXTERNAL_MEMORY_FEATURE_DEDICATED_ONLY_BIT_KHR = EXTERNAL_MEMORY_FEATURE_DEDICATED_ONLY_BIT;
const ExternalMemoryFeatureFlags EXTERNAL_MEMORY_FEATURE_EXPORTABLE_BIT_KHR     = EXTERNAL_MEMORY_FEATURE_EXPORTABLE_BIT;
const ExternalMemoryFeatureFlags EXTERNAL_MEMORY_FEATURE_IMPORTABLE_BIT_KHR     = EXTERNAL_MEMORY_FEATURE_IMPORTABLE_BIT;

alias ExternalSemaphoreHandleTypeFlags = vulkan::vk::VkExternalSemaphoreHandleTypeFlags;
alias ExternalSemaphoreHandleTypeFlagBits = ExternalSemaphoreHandleTypeFlags;
const ExternalSemaphoreHandleTypeFlags EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_FD_BIT            = 0x00000001;
const ExternalSemaphoreHandleTypeFlags EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_WIN32_BIT         = 0x00000002;
const ExternalSemaphoreHandleTypeFlags EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_WIN32_KMT_BIT     = 0x00000004;
const ExternalSemaphoreHandleTypeFlags EXTERNAL_SEMAPHORE_HANDLE_TYPE_D3D12_FENCE_BIT          = 0x00000008;
const ExternalSemaphoreHandleTypeFlags EXTERNAL_SEMAPHORE_HANDLE_TYPE_D3D11_FENCE_BIT          = EXTERNAL_SEMAPHORE_HANDLE_TYPE_D3D12_FENCE_BIT;
const ExternalSemaphoreHandleTypeFlags EXTERNAL_SEMAPHORE_HANDLE_TYPE_SYNC_FD_BIT              = 0x00000010;
const ExternalSemaphoreHandleTypeFlags EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_FD_BIT_KHR        = EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_FD_BIT;
const ExternalSemaphoreHandleTypeFlags EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_WIN32_BIT_KHR     = EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_WIN32_BIT;
const ExternalSemaphoreHandleTypeFlags EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_WIN32_KMT_BIT_KHR = EXTERNAL_SEMAPHORE_HANDLE_TYPE_OPAQUE_WIN32_KMT_BIT;
const ExternalSemaphoreHandleTypeFlags EXTERNAL_SEMAPHORE_HANDLE_TYPE_D3D12_FENCE_BIT_KHR      = EXTERNAL_SEMAPHORE_HANDLE_TYPE_D3D12_FENCE_BIT;
const ExternalSemaphoreHandleTypeFlags EXTERNAL_SEMAPHORE_HANDLE_TYPE_SYNC_FD_BIT_KHR          = EXTERNAL_SEMAPHORE_HANDLE_TYPE_SYNC_FD_BIT;

alias ExternalSemaphoreFeatureFlags = vulkan::vk::VkExternalSemaphoreFeatureFlags;
alias ExternalSemaphoreFeatureFlagBits = ExternalSemaphoreFeatureFlags;
const ExternalSemaphoreFeatureFlags EXTERNAL_SEMAPHORE_FEATURE_EXPORTABLE_BIT     = 0x00000001;
const ExternalSemaphoreFeatureFlags EXTERNAL_SEMAPHORE_FEATURE_IMPORTABLE_BIT     = 0x00000002;
const ExternalSemaphoreFeatureFlags EXTERNAL_SEMAPHORE_FEATURE_EXPORTABLE_BIT_KHR = EXTERNAL_SEMAPHORE_FEATURE_EXPORTABLE_BIT;
const ExternalSemaphoreFeatureFlags EXTERNAL_SEMAPHORE_FEATURE_IMPORTABLE_BIT_KHR = EXTERNAL_SEMAPHORE_FEATURE_IMPORTABLE_BIT;

alias SemaphoreImportFlags = vulkan::vk::VkSemaphoreImportFlags;
alias SemaphoreImportFlagBits = SemaphoreImportFlags;
const SemaphoreImportFlags SEMAPHORE_IMPORT_TEMPORARY_BIT     = 0x00000001;
const SemaphoreImportFlags SEMAPHORE_IMPORT_TEMPORARY_BIT_KHR = SEMAPHORE_IMPORT_TEMPORARY_BIT;

alias ExternalFenceHandleTypeFlags = vulkan::vk::VkExternalFenceHandleTypeFlags;
alias ExternalFenceHandleTypeFlagBits = ExternalFenceHandleTypeFlags;
const ExternalFenceHandleTypeFlags EXTERNAL_FENCE_HANDLE_TYPE_OPAQUE_FD_BIT            = 0x00000001;
const ExternalFenceHandleTypeFlags EXTERNAL_FENCE_HANDLE_TYPE_OPAQUE_WIN32_BIT         = 0x00000002;
const ExternalFenceHandleTypeFlags EXTERNAL_FENCE_HANDLE_TYPE_OPAQUE_WIN32_KMT_BIT     = 0x00000004;
const ExternalFenceHandleTypeFlags EXTERNAL_FENCE_HANDLE_TYPE_SYNC_FD_BIT              = 0x00000008;
const ExternalFenceHandleTypeFlags EXTERNAL_FENCE_HANDLE_TYPE_OPAQUE_FD_BIT_KHR        = EXTERNAL_FENCE_HANDLE_TYPE_OPAQUE_FD_BIT;
const ExternalFenceHandleTypeFlags EXTERNAL_FENCE_HANDLE_TYPE_OPAQUE_WIN32_BIT_KHR     = EXTERNAL_FENCE_HANDLE_TYPE_OPAQUE_WIN32_BIT;
const ExternalFenceHandleTypeFlags EXTERNAL_FENCE_HANDLE_TYPE_OPAQUE_WIN32_KMT_BIT_KHR = EXTERNAL_FENCE_HANDLE_TYPE_OPAQUE_WIN32_KMT_BIT;
const ExternalFenceHandleTypeFlags EXTERNAL_FENCE_HANDLE_TYPE_SYNC_FD_BIT_KHR          = EXTERNAL_FENCE_HANDLE_TYPE_SYNC_FD_BIT;

alias ExternalFenceFeatureFlags = vulkan::vk::VkExternalFenceFeatureFlags;
alias ExternalFenceFeatureFlagBits = ExternalFenceFeatureFlags;
const ExternalFenceFeatureFlags EXTERNAL_FENCE_FEATURE_EXPORTABLE_BIT     = 0x00000001;
const ExternalFenceFeatureFlags EXTERNAL_FENCE_FEATURE_IMPORTABLE_BIT     = 0x00000002;
const ExternalFenceFeatureFlags EXTERNAL_FENCE_FEATURE_EXPORTABLE_BIT_KHR = EXTERNAL_FENCE_FEATURE_EXPORTABLE_BIT;
const ExternalFenceFeatureFlags EXTERNAL_FENCE_FEATURE_IMPORTABLE_BIT_KHR = EXTERNAL_FENCE_FEATURE_IMPORTABLE_BIT;

alias FenceImportFlags = vulkan::vk::VkFenceImportFlags;
alias FenceImportFlagBits = FenceImportFlags;
const FenceImportFlags FENCE_IMPORT_TEMPORARY_BIT     = 0x00000001;
const FenceImportFlags FENCE_IMPORT_TEMPORARY_BIT_KHR = FENCE_IMPORT_TEMPORARY_BIT;

typedef SurfaceCounterFlagsEXT @constinit = uint;
alias SurfaceCounterFlagBitsEXT = SurfaceCounterFlagsEXT;
const SurfaceCounterFlagsEXT SURFACE_COUNTER_VBLANK_BIT_EXT = 0x00000001;
const SurfaceCounterFlagsEXT SURFACE_COUNTER_VBLANK_EXT     = SURFACE_COUNTER_VBLANK_BIT_EXT;

typedef PipelineViewportSwizzleStateCreateFlagsNV @constinit = uint;

typedef PipelineDiscardRectangleStateCreateFlagsEXT @constinit = uint;

typedef PipelineCoverageToColorStateCreateFlagsNV @constinit = uint;

typedef PipelineCoverageModulationStateCreateFlagsNV @constinit = uint;

typedef PipelineCoverageReductionStateCreateFlagsNV @constinit = uint;

typedef ValidationCacheCreateFlagsEXT @constinit = uint;

typedef DebugUtilsMessageSeverityFlagsEXT @constinit = uint;
alias DebugUtilsMessageSeverityFlagBitsEXT = DebugUtilsMessageSeverityFlagsEXT;
const DebugUtilsMessageSeverityFlagsEXT DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT = 0x00000001;
const DebugUtilsMessageSeverityFlagsEXT DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT    = 0x00000010;
const DebugUtilsMessageSeverityFlagsEXT DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT = 0x00000100;
const DebugUtilsMessageSeverityFlagsEXT DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT   = 0x00001000;

typedef DebugUtilsMessageTypeFlagsEXT @constinit = uint;
alias DebugUtilsMessageTypeFlagBitsEXT = DebugUtilsMessageTypeFlagsEXT;
const DebugUtilsMessageTypeFlagsEXT DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT                = 0x00000001;
const DebugUtilsMessageTypeFlagsEXT DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT             = 0x00000002;
const DebugUtilsMessageTypeFlagsEXT DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT            = 0x00000004;
const DebugUtilsMessageTypeFlagsEXT DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT = 0x00000008;

typedef DebugUtilsMessengerCreateFlagsEXT @constinit = uint;

typedef DebugUtilsMessengerCallbackDataFlagsEXT @constinit = uint;

typedef DeviceMemoryReportFlagsEXT @constinit = uint;

typedef PipelineRasterizationConservativeStateCreateFlagsEXT @constinit = uint;

alias DescriptorBindingFlags = vulkan::vk::VkDescriptorBindingFlags;
alias DescriptorBindingFlagBits = DescriptorBindingFlags;
const DescriptorBindingFlags DESCRIPTOR_BINDING_UPDATE_AFTER_BIND_BIT               = 0x00000001;
const DescriptorBindingFlags DESCRIPTOR_BINDING_UPDATE_UNUSED_WHILE_PENDING_BIT     = 0x00000002;
const DescriptorBindingFlags DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT                 = 0x00000004;
const DescriptorBindingFlags DESCRIPTOR_BINDING_VARIABLE_DESCRIPTOR_COUNT_BIT       = 0x00000008;
const DescriptorBindingFlags DESCRIPTOR_BINDING_UPDATE_AFTER_BIND_BIT_EXT           = DESCRIPTOR_BINDING_UPDATE_AFTER_BIND_BIT;
const DescriptorBindingFlags DESCRIPTOR_BINDING_UPDATE_UNUSED_WHILE_PENDING_BIT_EXT = DESCRIPTOR_BINDING_UPDATE_UNUSED_WHILE_PENDING_BIT;
const DescriptorBindingFlags DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT_EXT             = DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT;
const DescriptorBindingFlags DESCRIPTOR_BINDING_VARIABLE_DESCRIPTOR_COUNT_BIT_EXT   = DESCRIPTOR_BINDING_VARIABLE_DESCRIPTOR_COUNT_BIT;

typedef ConditionalRenderingFlagsEXT @constinit = uint;
alias ConditionalRenderingFlagBitsEXT = ConditionalRenderingFlagsEXT;
const ConditionalRenderingFlagsEXT CONDITIONAL_RENDERING_INVERTED_BIT_EXT = 0x00000001;

alias ResolveModeFlags = vulkan::vk::VkResolveModeFlags;
alias ResolveModeFlagBits = ResolveModeFlags;
const ResolveModeFlags RESOLVE_MODE_NONE                = 0x00000000;
const ResolveModeFlags RESOLVE_MODE_SAMPLE_ZERO_BIT     = 0x00000001;
const ResolveModeFlags RESOLVE_MODE_AVERAGE_BIT         = 0x00000002;
const ResolveModeFlags RESOLVE_MODE_MIN_BIT             = 0x00000004;
const ResolveModeFlags RESOLVE_MODE_MAX_BIT             = 0x00000008;
const ResolveModeFlags RESOLVE_MODE_NONE_KHR            = RESOLVE_MODE_NONE;
const ResolveModeFlags RESOLVE_MODE_SAMPLE_ZERO_BIT_KHR = RESOLVE_MODE_SAMPLE_ZERO_BIT;
const ResolveModeFlags RESOLVE_MODE_AVERAGE_BIT_KHR     = RESOLVE_MODE_AVERAGE_BIT;
const ResolveModeFlags RESOLVE_MODE_MIN_BIT_KHR         = RESOLVE_MODE_MIN_BIT;
const ResolveModeFlags RESOLVE_MODE_MAX_BIT_KHR         = RESOLVE_MODE_MAX_BIT;
const ResolveModeFlags RESOLVE_MODE_CUSTOM_BIT_EXT      = 0x00000020;

typedef PipelineRasterizationStateStreamCreateFlagsEXT @constinit = uint;

typedef PipelineRasterizationDepthClipStateCreateFlagsEXT @constinit = uint;

alias ToolPurposeFlags = vulkan::vk::VkToolPurposeFlags;
alias ToolPurposeFlagBits = ToolPurposeFlags;
const ToolPurposeFlags TOOL_PURPOSE_VALIDATION_BIT              = 0x00000001;
const ToolPurposeFlags TOOL_PURPOSE_PROFILING_BIT               = 0x00000002;
const ToolPurposeFlags TOOL_PURPOSE_TRACING_BIT                 = 0x00000004;
const ToolPurposeFlags TOOL_PURPOSE_ADDITIONAL_FEATURES_BIT     = 0x00000008;
const ToolPurposeFlags TOOL_PURPOSE_MODIFYING_FEATURES_BIT      = 0x00000010;
const ToolPurposeFlags TOOL_PURPOSE_VALIDATION_BIT_EXT          = TOOL_PURPOSE_VALIDATION_BIT;
const ToolPurposeFlags TOOL_PURPOSE_PROFILING_BIT_EXT           = TOOL_PURPOSE_PROFILING_BIT;
const ToolPurposeFlags TOOL_PURPOSE_TRACING_BIT_EXT             = TOOL_PURPOSE_TRACING_BIT;
const ToolPurposeFlags TOOL_PURPOSE_ADDITIONAL_FEATURES_BIT_EXT = TOOL_PURPOSE_ADDITIONAL_FEATURES_BIT;
const ToolPurposeFlags TOOL_PURPOSE_MODIFYING_FEATURES_BIT_EXT  = TOOL_PURPOSE_MODIFYING_FEATURES_BIT;
const ToolPurposeFlags TOOL_PURPOSE_DEBUG_REPORTING_BIT_EXT     = 0x00000020;
const ToolPurposeFlags TOOL_PURPOSE_DEBUG_MARKERS_BIT_EXT       = 0x00000040;

alias SubmitFlags = vulkan::vk::VkSubmitFlags;
alias SubmitFlagBits = SubmitFlags;
const SubmitFlags SUBMIT_PROTECTED_BIT     = 0x00000001;
const SubmitFlags SUBMIT_PROTECTED_BIT_KHR = SUBMIT_PROTECTED_BIT;

typedef HostImageCopyFlags @constinit = uint;
alias HostImageCopyFlagBits = HostImageCopyFlags;
const HostImageCopyFlags HOST_IMAGE_COPY_MEMCPY_BIT     = 0x00000001;
const HostImageCopyFlags HOST_IMAGE_COPY_MEMCPY         = HOST_IMAGE_COPY_MEMCPY_BIT;
const HostImageCopyFlags HOST_IMAGE_COPY_MEMCPY_BIT_EXT = HOST_IMAGE_COPY_MEMCPY_BIT;
const HostImageCopyFlags HOST_IMAGE_COPY_MEMCPY_EXT     = HOST_IMAGE_COPY_MEMCPY_BIT;

typedef PartitionedAccelerationStructureInstanceFlagsNV @constinit = uint;
alias PartitionedAccelerationStructureInstanceFlagBitsNV = PartitionedAccelerationStructureInstanceFlagsNV;
const PartitionedAccelerationStructureInstanceFlagsNV PARTITIONED_ACCELERATION_STRUCTURE_INSTANCE_FLAG_TRIANGLE_FACING_CULL_DISABLE_BIT_NV = 0x00000001;
const PartitionedAccelerationStructureInstanceFlagsNV PARTITIONED_ACCELERATION_STRUCTURE_INSTANCE_FLAG_TRIANGLE_FLIP_FACING_BIT_NV         = 0x00000002;
const PartitionedAccelerationStructureInstanceFlagsNV PARTITIONED_ACCELERATION_STRUCTURE_INSTANCE_FLAG_FORCE_OPAQUE_BIT_NV                 = 0x00000004;
const PartitionedAccelerationStructureInstanceFlagsNV PARTITIONED_ACCELERATION_STRUCTURE_INSTANCE_FLAG_FORCE_NO_OPAQUE_BIT_NV              = 0x00000008;
const PartitionedAccelerationStructureInstanceFlagsNV PARTITIONED_ACCELERATION_STRUCTURE_INSTANCE_FLAG_ENABLE_EXPLICIT_BOUNDING_BOX_NV     = 0x00000010;

typedef GraphicsPipelineLibraryFlagsEXT @constinit = uint;
alias GraphicsPipelineLibraryFlagBitsEXT = GraphicsPipelineLibraryFlagsEXT;
const GraphicsPipelineLibraryFlagsEXT GRAPHICS_PIPELINE_LIBRARY_VERTEX_INPUT_INTERFACE_BIT_EXT    = 0x00000001;
const GraphicsPipelineLibraryFlagsEXT GRAPHICS_PIPELINE_LIBRARY_PRE_RASTERIZATION_SHADERS_BIT_EXT = 0x00000002;
const GraphicsPipelineLibraryFlagsEXT GRAPHICS_PIPELINE_LIBRARY_FRAGMENT_SHADER_BIT_EXT           = 0x00000004;
const GraphicsPipelineLibraryFlagsEXT GRAPHICS_PIPELINE_LIBRARY_FRAGMENT_OUTPUT_INTERFACE_BIT_EXT = 0x00000008;

typedef ImageCompressionFlagsEXT @constinit = uint;
alias ImageCompressionFlagBitsEXT = ImageCompressionFlagsEXT;
const ImageCompressionFlagsEXT IMAGE_COMPRESSION_DEFAULT_EXT             = 0x00000000;
const ImageCompressionFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_DEFAULT_EXT  = 0x00000001;
const ImageCompressionFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_EXPLICIT_EXT = 0x00000002;
const ImageCompressionFlagsEXT IMAGE_COMPRESSION_DISABLED_EXT            = 0x00000004;

typedef ImageCompressionFixedRateFlagsEXT @constinit = uint;
alias ImageCompressionFixedRateFlagBitsEXT = ImageCompressionFixedRateFlagsEXT;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_NONE_EXT      = 0x00000000;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_1BPC_BIT_EXT  = 0x00000001;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_2BPC_BIT_EXT  = 0x00000002;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_3BPC_BIT_EXT  = 0x00000004;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_4BPC_BIT_EXT  = 0x00000008;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_5BPC_BIT_EXT  = 0x00000010;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_6BPC_BIT_EXT  = 0x00000020;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_7BPC_BIT_EXT  = 0x00000040;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_8BPC_BIT_EXT  = 0x00000080;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_9BPC_BIT_EXT  = 0x00000100;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_10BPC_BIT_EXT = 0x00000200;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_11BPC_BIT_EXT = 0x00000400;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_12BPC_BIT_EXT = 0x00000800;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_13BPC_BIT_EXT = 0x00001000;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_14BPC_BIT_EXT = 0x00002000;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_15BPC_BIT_EXT = 0x00004000;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_16BPC_BIT_EXT = 0x00008000;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_17BPC_BIT_EXT = 0x00010000;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_18BPC_BIT_EXT = 0x00020000;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_19BPC_BIT_EXT = 0x00040000;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_20BPC_BIT_EXT = 0x00080000;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_21BPC_BIT_EXT = 0x00100000;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_22BPC_BIT_EXT = 0x00200000;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_23BPC_BIT_EXT = 0x00400000;
const ImageCompressionFixedRateFlagsEXT IMAGE_COMPRESSION_FIXED_RATE_24BPC_BIT_EXT = 0x00800000;

typedef RenderingAttachmentFlagsKHR @constinit = uint;
alias RenderingAttachmentFlagBitsKHR = RenderingAttachmentFlagsKHR;
const RenderingAttachmentFlagsKHR RENDERING_ATTACHMENT_INPUT_ATTACHMENT_FEEDBACK_BIT_KHR        = 0x00000001;
const RenderingAttachmentFlagsKHR RENDERING_ATTACHMENT_RESOLVE_SKIP_TRANSFER_FUNCTION_BIT_KHR   = 0x00000002;
const RenderingAttachmentFlagsKHR RENDERING_ATTACHMENT_RESOLVE_ENABLE_TRANSFER_FUNCTION_BIT_KHR = 0x00000004;

typedef ResolveImageFlagsKHR @constinit = uint;
alias ResolveImageFlagBitsKHR = ResolveImageFlagsKHR;
const ResolveImageFlagsKHR RESOLVE_IMAGE_SKIP_TRANSFER_FUNCTION_BIT_KHR   = 0x00000001;
const ResolveImageFlagsKHR RESOLVE_IMAGE_ENABLE_TRANSFER_FUNCTION_BIT_KHR = 0x00000002;

typedef DeviceAddressBindingFlagsEXT @constinit = uint;
alias DeviceAddressBindingFlagBitsEXT = DeviceAddressBindingFlagsEXT;
const DeviceAddressBindingFlagsEXT DEVICE_ADDRESS_BINDING_INTERNAL_OBJECT_BIT_EXT = 0x00000001;

typedef OpticalFlowGridSizeFlagsNV @constinit = uint;
alias OpticalFlowGridSizeFlagBitsNV = OpticalFlowGridSizeFlagsNV;
const OpticalFlowGridSizeFlagsNV OPTICAL_FLOW_GRID_SIZE_UNKNOWN_NV = 0x00000000;
const OpticalFlowGridSizeFlagsNV OPTICAL_FLOW_GRID_SIZE_1X1_BIT_NV = 0x00000001;
const OpticalFlowGridSizeFlagsNV OPTICAL_FLOW_GRID_SIZE_2X2_BIT_NV = 0x00000002;
const OpticalFlowGridSizeFlagsNV OPTICAL_FLOW_GRID_SIZE_4X4_BIT_NV = 0x00000004;
const OpticalFlowGridSizeFlagsNV OPTICAL_FLOW_GRID_SIZE_8X8_BIT_NV = 0x00000008;

typedef OpticalFlowUsageFlagsNV @constinit = uint;
alias OpticalFlowUsageFlagBitsNV = OpticalFlowUsageFlagsNV;
const OpticalFlowUsageFlagsNV OPTICAL_FLOW_USAGE_UNKNOWN_NV         = 0x00000000;
const OpticalFlowUsageFlagsNV OPTICAL_FLOW_USAGE_INPUT_BIT_NV       = 0x00000001;
const OpticalFlowUsageFlagsNV OPTICAL_FLOW_USAGE_OUTPUT_BIT_NV      = 0x00000002;
const OpticalFlowUsageFlagsNV OPTICAL_FLOW_USAGE_HINT_BIT_NV        = 0x00000004;
const OpticalFlowUsageFlagsNV OPTICAL_FLOW_USAGE_COST_BIT_NV        = 0x00000008;
const OpticalFlowUsageFlagsNV OPTICAL_FLOW_USAGE_GLOBAL_FLOW_BIT_NV = 0x00000010;

typedef OpticalFlowSessionCreateFlagsNV @constinit = uint;
alias OpticalFlowSessionCreateFlagBitsNV = OpticalFlowSessionCreateFlagsNV;
const OpticalFlowSessionCreateFlagsNV OPTICAL_FLOW_SESSION_CREATE_ENABLE_HINT_BIT_NV        = 0x00000001;
const OpticalFlowSessionCreateFlagsNV OPTICAL_FLOW_SESSION_CREATE_ENABLE_COST_BIT_NV        = 0x00000002;
const OpticalFlowSessionCreateFlagsNV OPTICAL_FLOW_SESSION_CREATE_ENABLE_GLOBAL_FLOW_BIT_NV = 0x00000004;
const OpticalFlowSessionCreateFlagsNV OPTICAL_FLOW_SESSION_CREATE_ALLOW_REGIONS_BIT_NV      = 0x00000008;
const OpticalFlowSessionCreateFlagsNV OPTICAL_FLOW_SESSION_CREATE_BOTH_DIRECTIONS_BIT_NV    = 0x00000010;

typedef OpticalFlowExecuteFlagsNV @constinit = uint;
alias OpticalFlowExecuteFlagBitsNV = OpticalFlowExecuteFlagsNV;
const OpticalFlowExecuteFlagsNV OPTICAL_FLOW_EXECUTE_DISABLE_TEMPORAL_HINTS_BIT_NV = 0x00000001;

typedef FrameBoundaryFlagsEXT @constinit = uint;
alias FrameBoundaryFlagBitsEXT = FrameBoundaryFlagsEXT;
const FrameBoundaryFlagsEXT FRAME_BOUNDARY_FRAME_END_BIT_EXT = 0x00000001;

typedef PresentScalingFlagsKHR @constinit = uint;
alias PresentScalingFlagBitsKHR = PresentScalingFlagsKHR;
const PresentScalingFlagsKHR PRESENT_SCALING_ONE_TO_ONE_BIT_KHR           = 0x00000001;
const PresentScalingFlagsKHR PRESENT_SCALING_ONE_TO_ONE_BIT_EXT           = PRESENT_SCALING_ONE_TO_ONE_BIT_KHR;
const PresentScalingFlagsKHR PRESENT_SCALING_ASPECT_RATIO_STRETCH_BIT_KHR = 0x00000002;
const PresentScalingFlagsKHR PRESENT_SCALING_ASPECT_RATIO_STRETCH_BIT_EXT = PRESENT_SCALING_ASPECT_RATIO_STRETCH_BIT_KHR;
const PresentScalingFlagsKHR PRESENT_SCALING_STRETCH_BIT_KHR              = 0x00000004;
const PresentScalingFlagsKHR PRESENT_SCALING_STRETCH_BIT_EXT              = PRESENT_SCALING_STRETCH_BIT_KHR;

typedef PresentGravityFlagsKHR @constinit = uint;
alias PresentGravityFlagBitsKHR = PresentGravityFlagsKHR;
const PresentGravityFlagsKHR PRESENT_GRAVITY_MIN_BIT_KHR      = 0x00000001;
const PresentGravityFlagsKHR PRESENT_GRAVITY_MIN_BIT_EXT      = PRESENT_GRAVITY_MIN_BIT_KHR;
const PresentGravityFlagsKHR PRESENT_GRAVITY_MAX_BIT_KHR      = 0x00000002;
const PresentGravityFlagsKHR PRESENT_GRAVITY_MAX_BIT_EXT      = PRESENT_GRAVITY_MAX_BIT_KHR;
const PresentGravityFlagsKHR PRESENT_GRAVITY_CENTERED_BIT_KHR = 0x00000004;
const PresentGravityFlagsKHR PRESENT_GRAVITY_CENTERED_BIT_EXT = PRESENT_GRAVITY_CENTERED_BIT_KHR;

typedef ShaderCreateFlagsEXT @constinit = uint;
alias ShaderCreateFlagBitsEXT = ShaderCreateFlagsEXT;
const ShaderCreateFlagsEXT SHADER_CREATE_LINK_STAGE_BIT_EXT                       = 0x00000001;
const ShaderCreateFlagsEXT SHADER_CREATE_DESCRIPTOR_HEAP_BIT_EXT                  = 0x00000400;
const ShaderCreateFlagsEXT SHADER_CREATE_ALLOW_VARYING_SUBGROUP_SIZE_BIT_EXT      = 0x00000002;
const ShaderCreateFlagsEXT SHADER_CREATE_REQUIRE_FULL_SUBGROUPS_BIT_EXT           = 0x00000004;
const ShaderCreateFlagsEXT SHADER_CREATE_NO_TASK_SHADER_BIT_EXT                   = 0x00000008;
const ShaderCreateFlagsEXT SHADER_CREATE_DISPATCH_BASE_BIT_EXT                    = 0x00000010;
const ShaderCreateFlagsEXT SHADER_CREATE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_EXT = 0x00000020;
const ShaderCreateFlagsEXT SHADER_CREATE_FRAGMENT_DENSITY_MAP_ATTACHMENT_BIT_EXT  = 0x00000040;
const ShaderCreateFlagsEXT SHADER_CREATE_INDIRECT_BINDABLE_BIT_EXT                = 0x00000080;
const ShaderCreateFlagsEXT SHADER_CREATE_64_BIT_INDEXING_BIT_EXT                  = 0x00008000;

typedef TileShadingRenderPassFlagsQCOM @constinit = uint;
alias TileShadingRenderPassFlagBitsQCOM = TileShadingRenderPassFlagsQCOM;
const TileShadingRenderPassFlagsQCOM TILE_SHADING_RENDER_PASS_ENABLE_BIT_QCOM             = 0x00000001;
const TileShadingRenderPassFlagsQCOM TILE_SHADING_RENDER_PASS_PER_TILE_EXECUTION_BIT_QCOM = 0x00000002;

typedef PhysicalDeviceSchedulingControlsFlagsARM @constinit = ulong;
alias PhysicalDeviceSchedulingControlsFlagBitsARM = PhysicalDeviceSchedulingControlsFlagsARM;
const PhysicalDeviceSchedulingControlsFlagsARM PHYSICAL_DEVICE_SCHEDULING_CONTROLS_SHADER_CORE_COUNT_ARM = 0x0000000000000001;

typedef PresentStageFlagsEXT @constinit = uint;
alias PresentStageFlagBitsEXT = PresentStageFlagsEXT;
const PresentStageFlagsEXT PRESENT_STAGE_QUEUE_OPERATIONS_END_BIT_EXT      = 0x00000001;
const PresentStageFlagsEXT PRESENT_STAGE_REQUEST_DEQUEUED_BIT_EXT          = 0x00000002;
const PresentStageFlagsEXT PRESENT_STAGE_IMAGE_FIRST_PIXEL_OUT_BIT_EXT     = 0x00000004;
const PresentStageFlagsEXT PRESENT_STAGE_IMAGE_FIRST_PIXEL_VISIBLE_BIT_EXT = 0x00000008;

typedef PastPresentationTimingFlagsEXT @constinit = uint;
alias PastPresentationTimingFlagBitsEXT = PastPresentationTimingFlagsEXT;
const PastPresentationTimingFlagsEXT PAST_PRESENTATION_TIMING_ALLOW_PARTIAL_RESULTS_BIT_EXT      = 0x00000001;
const PastPresentationTimingFlagsEXT PAST_PRESENTATION_TIMING_ALLOW_OUT_OF_ORDER_RESULTS_BIT_EXT = 0x00000002;

typedef PresentTimingInfoFlagsEXT @constinit = uint;
alias PresentTimingInfoFlagBitsEXT = PresentTimingInfoFlagsEXT;
const PresentTimingInfoFlagsEXT PRESENT_TIMING_INFO_PRESENT_AT_RELATIVE_TIME_BIT_EXT         = 0x00000001;
const PresentTimingInfoFlagsEXT PRESENT_TIMING_INFO_PRESENT_AT_NEAREST_REFRESH_CYCLE_BIT_EXT = 0x00000002;

typedef PerformanceCounterDescriptionFlagsARM @constinit = uint;

typedef AccessFlags3KHR @constinit = ulong;
alias AccessFlagBits3KHR = AccessFlags3KHR;
const AccessFlags3KHR ACCESS_3_NONE_KHR = 0x0000000000000000;

// Enum and bitmask aliases
alias MemoryUnmapFlagsKHR = MemoryUnmapFlags;
alias GeometryFlagsNV = GeometryFlagsKHR;
alias GeometryInstanceFlagsNV = GeometryInstanceFlagsKHR;
alias BuildAccelerationStructureFlagsNV = BuildAccelerationStructureFlagsKHR;
alias PrivateDataSlotCreateFlagsEXT = PrivateDataSlotCreateFlags;
alias DescriptorUpdateTemplateCreateFlagsKHR = DescriptorUpdateTemplateCreateFlags;
alias PipelineCreationFeedbackFlagsEXT = PipelineCreationFeedbackFlags;
alias SemaphoreWaitFlagsKHR = SemaphoreWaitFlags;
alias AccessFlags2KHR = AccessFlags2;
alias PipelineStageFlags2KHR = PipelineStageFlags2;
alias FormatFeatureFlags2KHR = FormatFeatureFlags2;
alias MemoryDecompressionMethodFlagsNV = MemoryDecompressionMethodFlagsEXT;
alias RenderingFlagsKHR = RenderingFlags;
alias PipelineCreateFlags2KHR = PipelineCreateFlags2;
alias BufferUsageFlags2KHR = BufferUsageFlags2;
alias PeerMemoryFeatureFlagsKHR = PeerMemoryFeatureFlags;
alias MemoryAllocateFlagsKHR = MemoryAllocateFlags;
alias CommandPoolTrimFlagsKHR = CommandPoolTrimFlags;
alias ExternalMemoryHandleTypeFlagsKHR = ExternalMemoryHandleTypeFlags;
alias ExternalMemoryFeatureFlagsKHR = ExternalMemoryFeatureFlags;
alias ExternalSemaphoreHandleTypeFlagsKHR = ExternalSemaphoreHandleTypeFlags;
alias ExternalSemaphoreFeatureFlagsKHR = ExternalSemaphoreFeatureFlags;
alias SemaphoreImportFlagsKHR = SemaphoreImportFlags;
alias ExternalFenceHandleTypeFlagsKHR = ExternalFenceHandleTypeFlags;
alias ExternalFenceFeatureFlagsKHR = ExternalFenceFeatureFlags;
alias FenceImportFlagsKHR = FenceImportFlags;
alias DescriptorBindingFlagsEXT = DescriptorBindingFlags;
alias ResolveModeFlagsKHR = ResolveModeFlags;
alias ToolPurposeFlagsEXT = ToolPurposeFlags;
alias SubmitFlagsKHR = SubmitFlags;
alias HostImageCopyFlagsEXT = HostImageCopyFlags;
alias PresentScalingFlagsEXT = PresentScalingFlagsKHR;
alias PresentGravityFlagsEXT = PresentGravityFlagsKHR;
alias RayTracingInvocationReorderModeNV = RayTracingInvocationReorderModeEXT;
alias DescriptorUpdateTemplateTypeKHR = DescriptorUpdateTemplateType;
alias PointClippingBehaviorKHR = PointClippingBehavior;
alias QueueGlobalPriorityKHR = QueueGlobalPriority;
alias QueueGlobalPriorityEXT = QueueGlobalPriority;
alias TimeDomainEXT = TimeDomainKHR;
alias ResolveModeFlagBitsKHR = ResolveModeFlagBits;
alias DescriptorBindingFlagBitsEXT = DescriptorBindingFlagBits;
alias SemaphoreTypeKHR = SemaphoreType;
alias GeometryFlagBitsNV = GeometryFlagBitsKHR;
alias GeometryInstanceFlagBitsNV = GeometryInstanceFlagBitsKHR;
alias BuildAccelerationStructureFlagBitsNV = BuildAccelerationStructureFlagBitsKHR;
alias CopyAccelerationStructureModeNV = CopyAccelerationStructureModeKHR;
alias AccelerationStructureTypeNV = AccelerationStructureTypeKHR;
alias GeometryTypeNV = GeometryTypeKHR;
alias RayTracingShaderGroupTypeNV = RayTracingShaderGroupTypeKHR;
alias PipelineCreationFeedbackFlagBitsEXT = PipelineCreationFeedbackFlagBits;
alias SemaphoreWaitFlagBitsKHR = SemaphoreWaitFlagBits;
alias LineRasterizationModeKHR = LineRasterizationMode;
alias LineRasterizationModeEXT = LineRasterizationMode;
alias ToolPurposeFlagBitsEXT = ToolPurposeFlagBits;
alias AccessFlagBits2KHR = AccessFlagBits2;
alias PipelineStageFlagBits2KHR = PipelineStageFlagBits2;
alias HostImageCopyFlagBitsEXT = HostImageCopyFlagBits;
alias FormatFeatureFlagBits2KHR = FormatFeatureFlagBits2;
alias RenderingFlagBitsKHR = RenderingFlagBits;
alias PipelineRobustnessBufferBehaviorEXT = PipelineRobustnessBufferBehavior;
alias PipelineRobustnessImageBehaviorEXT = PipelineRobustnessImageBehavior;
alias MemoryDecompressionMethodFlagBitsNV = MemoryDecompressionMethodFlagBitsEXT;
alias PipelineCreateFlagBits2KHR = PipelineCreateFlagBits2;
alias BufferUsageFlagBits2KHR = BufferUsageFlagBits2;
alias ScopeNV = ScopeKHR;
alias ComponentTypeNV = ComponentTypeKHR;
alias ExternalMemoryHandleTypeFlagBitsKHR = ExternalMemoryHandleTypeFlagBits;
alias ExternalMemoryFeatureFlagBitsKHR = ExternalMemoryFeatureFlagBits;
alias ExternalSemaphoreHandleTypeFlagBitsKHR = ExternalSemaphoreHandleTypeFlagBits;
alias ExternalSemaphoreFeatureFlagBitsKHR = ExternalSemaphoreFeatureFlagBits;
alias SemaphoreImportFlagBitsKHR = SemaphoreImportFlagBits;
alias ExternalFenceHandleTypeFlagBitsKHR = ExternalFenceHandleTypeFlagBits;
alias ExternalFenceFeatureFlagBitsKHR = ExternalFenceFeatureFlagBits;
alias FenceImportFlagBitsKHR = FenceImportFlagBits;
alias PeerMemoryFeatureFlagBitsKHR = PeerMemoryFeatureFlagBits;
alias MemoryAllocateFlagBitsKHR = MemoryAllocateFlagBits;
alias TessellationDomainOriginKHR = TessellationDomainOrigin;
alias SamplerYcbcrModelConversionKHR = SamplerYcbcrModelConversion;
alias SamplerYcbcrRangeKHR = SamplerYcbcrRange;
alias ChromaLocationKHR = ChromaLocation;
alias SamplerReductionModeEXT = SamplerReductionMode;
alias ShaderFloatControlsIndependenceKHR = ShaderFloatControlsIndependence;
alias SubmitFlagBitsKHR = SubmitFlagBits;
alias PresentScalingFlagBitsEXT = PresentScalingFlagBitsKHR;
alias PresentGravityFlagBitsEXT = PresentGravityFlagBitsKHR;
alias MemoryUnmapFlagBitsKHR = MemoryUnmapFlagBits;
alias DriverIdKHR = DriverId;

// Extension structure type values used by the RHI and absent from the core Vulkan 1.3 binding.
const StructureType DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT = 1000128004;
const StructureType PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_FEATURES_KHR = 1000150013;
const StructureType PHYSICAL_DEVICE_LINE_RASTERIZATION_FEATURES_KHR = 1000259000;
const StructureType PHYSICAL_DEVICE_MAINTENANCE_5_FEATURES_KHR = 1000470000;
const StructureType PHYSICAL_DEVICE_PRESENT_ID_FEATURES_KHR = 1000294001;
const StructureType PHYSICAL_DEVICE_PRESENT_WAIT_FEATURES_KHR = 1000248000;
const StructureType PHYSICAL_DEVICE_RAY_QUERY_FEATURES_KHR = 1000348013;
const StructureType PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_FEATURES_KHR = 1000347000;
const StructureType SWAPCHAIN_CREATE_INFO_KHR = 1000001000;
const StructureType WIN32_SURFACE_CREATE_INFO_KHR = 1000009000;
