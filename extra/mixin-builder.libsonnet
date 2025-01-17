// This file is the top level file used for generating all of the dashboards and rules for a product

// MaC imports
local alertFunctions = import './lib/alert-functions.libsonnet';
local dashboardFunctions = import './lib/dashboard-functions.libsonnet';
local sliElementFunctions = import './lib/sli-element-functions.libsonnet';
local macConfig = import './mac-config.libsonnet';

// Updates the SLI spec list passed from mixin file by adding additional values
// @param config The config for the service defined in the mixin file
// @param passedSliSpecList The list of SLI specs defined in the mixin file before being updated
// @returns The updated SLI spec list
local updateSliSpecList(config, passedSliSpecList) =
  passedSliSpecList + {
    [journeyKey]+: {
      [sliKey]+: {
        sliLabels: {
          service: config.product,
          slo: sliKey,
          environment: config.environment,
          journey: journeyKey,
          mac_version: config.macVersion,
        },
        dashboardSliLabelSelectors: "service='%(service)s', slo='%(slo)s', environment='$environment',\n          journey='%(journey)s'" % {
          service: config.product,
          slo: sliKey,
          environment: config.environment,
          journey: journeyKey,
        },
        ruleSliLabelSelectors: "service='%(service)s', slo='%(slo)s', environment='%(environment)s',\n          journey='%(journey)s'" % {
          service: config.product,
          slo: sliKey,
          environment: config.environment,
          journey: journeyKey,
        },
      }
      for sliKey in std.objectFields(passedSliSpecList[journeyKey])
    }
    for journeyKey in std.objectFields(passedSliSpecList)
  };

// Creates an SLI with its standard dashboard elements, unique dashboard elements, recording
// rules, alerting rules and alerts
// @param config The config for the service defined in the mixin file
// @param sliSpecList The list of SLI specs defined in the mixin file
// @param sliKey The key of the current SLI having rules generated
// @param journeyKey The key of the journey containing the SLI having rules generated
// @returns The SLI with standard elements
local createSli(config, sliSpecList, sliKey, journeyKey) =
  local sliSpec = sliSpecList[journeyKey][sliKey];

  if std.objectHas(macConfig.sliMetricLibs, sliSpec.sliType) then
    sliElementFunctions.createRecordingRules(sliSpec, config) +
    sliElementFunctions.createSliStandardElements(sliKey, sliSpec) +
    dashboardFunctions.createDashboardStandardElements(sliKey, journeyKey, sliSpec, config) +
    alertFunctions.createBurnRateRules(sliSpec) +
    alertFunctions.createBurnRateAlerts(config, sliSpec, sliKey, journeyKey)
  else error 'undefined sli type';

// Creates a list of all the SLIs in a service with their standard dashboard elements, unique
// dashboard elements, recording rules, alerting rules and alerts
// @param config The config for the service defined in the mixin file
// @param sliSpecList The list of SLI specs defined in the mixin file
// @returns The list of SLIs with standard elements
local createSliList(config, sliSpecList) =
  {
    [journeyKey]+: {
      [sliKey]+:
        createSli(config, sliSpecList, sliKey, journeyKey)
      for sliKey in std.objectFields(sliSpecList[journeyKey])
    }
    for journeyKey in std.objectFields(sliSpecList)
  };

// Creates the links to other dashboards
// @param config The config for the service defined in the mixin file
// @returns A list of the links to other dashboards
local createLinks(config) =
  [
    {
      asDropdown: false,
      icon: 'dashboard',
      includeVars: true,
      tags: ['summary-view'],
      title: 'summary-view',
      type: 'dashboards',
    },
    {
      asDropdown: false,
      icon: 'dashboard',
      includeVars: true,
      tags: [config.product, 'product-view'],
      title: 'product-view',
      type: 'dashboards',
    },
    {
      asDropdown: true,
      icon: 'dashboard',
      includeVars: true,
      tags: [config.product, 'journey-view'],
      title: 'journey-view',
      type: 'dashboards',
    },
    {
      asDropdown: true,
      icon: 'dashboard',
      includeVars: true,
      tags: [config.product, 'detail-view'],
      title: 'detail-view',
      type: 'dashboards',
    },
  ];

// Creates the JSON defining the recording rules for the SLIs in a service
// @param config The config for the service defined in the mixin file
// @param sliList The list of SLIs for a service
// @returns JSON defining the recording rules
local createPrometheusRules(config, sliList) =
  {
    groups+: [{
      name: config.product + '_' + config.environment + '_recordingrules',
      rules: std.flattenArrays([
        sli.recording_rules
        for journeyKey in std.objectFields(sliList)
        for sli in std.objectValues(sliList[journeyKey])
      ]),
    }],
  };

// Creates the JSON defining the alerting rules for the SLIs in a service
// @param config The config for the service defined in the mixin file
// @param sliList The list of SLIs for a service
// @returns JSON defining the alerting rules
local createPrometheusAlerts(config, sliList) =
  {
    groups+: [{
      name: config.product + '_' + config.environment + '_alertrules',
      rules: std.flattenArrays([
        sli.alerts
        for journeyKey in std.objectFields(sliList)
        for sli in std.objectValues(sliList[journeyKey])
      ]),
    }],
  };

local buildMixin(config, passedSliSpecList) =
  local sliSpecList = updateSliSpecList(config, passedSliSpecList);

  local sliList = createSliList(config, sliSpecList);

  // Define standard set of links to use in each dashboard
  local links = createLinks(config);

  {
    grafanaDashboardFolder: config.product,
    grafanaDashboards+: dashboardFunctions.createJourneyDashboards(config, sliList, links) +
      dashboardFunctions.createProductDashboard(config, sliList, links) +
      dashboardFunctions.createDetailDashboards(config, links, sliSpecList),

    prometheusRules+: createPrometheusRules(config, sliList),
    prometheusAlerts+: createPrometheusAlerts(config, sliList),
  };

// File exports
{
  buildMixin(config, passedSliSpecList): buildMixin(config, passedSliSpecList),
}
