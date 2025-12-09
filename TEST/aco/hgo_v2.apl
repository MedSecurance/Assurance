
ac_pattern('HGO_StabVida_Assurance_Case',
    [],
    goal('G0',
        'Safe and secure integration with third-party systems is achieved. The Dr.Vida system integrates securely with healthcare third-party systems, ensuring confidentiality, integrity, availability, and clear responsibility demarcation.',
        [
            context("Case: HGO StabVida Assurance Case — Safe and Secure Integration with Third Party Systems"),
            assumption('The third-party provider and underlying infrastructure (virtualization, storage, networking) implement appropriate physical and infrastructure-level security controls.'),
            assumption('Operating systems, databases, and middleware used by StabVida are installed, configured, and kept patched according to defined security baselines.'),
            assumption('The surrounding network environment provides basic protections (e.g., firewalling, routing, segmentation) consistent with the assumed threat model.'),
            assumption('Healthcare professionals and other staff using Dr.Vida follow organizational security policies and receive appropriate security awareness training.'),
            assumption('End-user devices (e.g., clinicians’ workstations, patient mobile phones) and local facilities are protected physically, according to organizational policies.'),
            assumption('Users keep their authentication credentials confidential and follow organizational rules for credential management (e.g., not sharing passwords).')
        ],
        [
            goal('G1',
                'All communications with third-party systems use validated secure channels and are adequately protected against unauthorized disclosure during collection, storage, and sharing.',
                [],
                [
                    strategy('Decompose by data state (in transit, at rest) and by access control for different user and service channels (patients, clinicians, internal services, external services).',
                        [],
                        [
                            goal('G11',
                                'Data in transit between the Dr.Vida system and third-party systems is confidential.',
                                [],
                                [
                                    goal('G111',
                                        'All communications between the Dr.Vida cloud endpoint and the third-party cloud endpoint use strong, up-to-date transport encryption.',
                                        [],
                                        [
                                            evidence(tlsConfigurationScanReportVidaAPI,
                                                'A TLS configuration scan report for the Dr.Vida cloud endpoint shows only approved protocol versions and cipher suites and confirms that insecure fallback is not possible.',
                                                []
                                            )
                                        ]
                                    ),
                                    goal('G1112',
                                        'Certificates used for API-to-API communications are valid, not expired, issued by trusted CAs, and protected from misuse.',
                                        [],
                                        [
                                            evidence(certificateManagementReviewVidaAPI,
                                                'A certificate inventory and management review, together with automated certificate checks, confirms that all certificates used for API-to-API communications are valid, trusted, and properly protected.',
                                                []
                                            )
                                        ]
                                    ),
                                    goal('G112',
                                        'Data in transit between Dr.Vida services APIs and external cloud data sources (third-party cloud APIs) is encrypted and authenticated.',
                                        [],
                                        [
                                            goal('G1121',
                                                'All outbound and inbound API calls to external sources use secure channels (e.g., TLS) and authenticated endpoints.',
                                                [],
                                                [
                                                    evidence(apiGatewaySecurityConfiguration,
                                                        'An API gateway configuration review and security testing confirm that all outbound and inbound API calls to external sources use TLS and authenticated endpoints.',
                                                        []
                                                    )
                                                ]
                                            ),
                                            goal('G1122',
                                                'No sensitive PHR data is sent over unprotected or legacy protocols.',
                                                [],
                                                [
                                                    evidence(networkTrafficAndPenetrationTestResults,
                                                        'Network traffic analysis and penetration testing show that no sensitive PHR data is transmitted over unprotected or legacy protocols.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    )
                                ]
                            ),
                            goal('G12',
                                'PHR and exam data at rest in Dr.Vida cloud storage are confidential.',
                                [],
                                [
                                    goal('G121',
                                        'All PHR data and uploaded multimedia (analysis results) stored in cloud databases and object storage are encrypted at rest.',
                                        [],
                                        [
                                            goal('G1211',
                                                'Encryption at rest is enabled and enforced on all PHR databases.',
                                                [],
                                                [
                                                    evidence(dbEncryptionConfigurationAudit,
                                                        'Cloud configuration audits and database configuration inspection tools confirm that encryption at rest is enabled and enforced on all PHR databases.',
                                                        []
                                                    )
                                                ]
                                            ),
                                            goal('G1212',
                                                'Encryption at rest is enabled and enforced for object storage buckets containing PHR images and documents.',
                                                [],
                                                [
                                                    evidence(objectStorageEncryptionAudit,
                                                        'Storage configuration audits and cloud security scanner tools confirm that encryption at rest is enabled and enforced for all object storage buckets containing PHR images and documents.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    ),
                                    goal('G122',
                                        'Cryptographic key material is managed securely.',
                                        [],
                                        [
                                            goal('G1221',
                                                'Encryption keys are stored and handled using a dedicated key management service (KMS) or hardware security module (HSM) with appropriate access controls.',
                                                [],
                                                [
                                                    evidence(kmsHSMConfigurationReview,
                                                        'KMS/HSM configuration reviews and security audits confirm that encryption keys are stored and handled using a dedicated service with appropriate access controls.',
                                                        []
                                                    )
                                                ]
                                            ),
                                            goal('G1222',
                                                'Key rotation policies exist and are implemented according to defined schedules or triggers.',
                                                [],
                                                [
                                                    evidence(keyRotationEvidence,
                                                        'Policy reviews and records of executed key rotations (e.g., logs, KMS rotation records) confirm that key rotation policies exist and are implemented according to defined schedules or triggers.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    )
                                ]
                            ),
                            goal('G13',
                                'Only authorized users and components can access the API management plane.',
                                [],
                                [
                                    goal('G131',
                                        'Access control policies restrict database and storage access to the minimal necessary services and roles.',
                                        [],
                                        [
                                            goal('G1311',
                                                'Database accounts, service accounts, and roles follow least-privilege principles.',
                                                [],
                                                [
                                                    evidence(iamConfigurationAudit,
                                                        'IAM configuration audit tools confirm that database accounts, service accounts, and roles follow least-privilege principles.',
                                                        []
                                                    )
                                                ]
                                            ),
                                            goal('G1312',
                                                'There are no “backdoor” accounts or generic high-privilege accounts without justification and monitoring.',
                                                [],
                                                [
                                                    evidence(accountInventoryAndPenetrationTestResults,
                                                        'Account inventory reviews and penetration test results confirm that there are no undocumented “backdoor” accounts or unjustified high-privilege accounts.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    ),
                                    goal('G132',
                                        'Administrative access to the API management plane is enforced by robust authentication and authorization mechanisms.',
                                        [],
                                        [
                                            goal('G1321',
                                                'User authentication mechanisms (e.g., username/password, MFA where applicable) meet defined security requirements.',
                                                [],
                                                [
                                                    evidence(authenticationDesignAndSecurityTests,
                                                        'Authentication design reviews and security testing tool results confirm that user authentication mechanisms meet defined security requirements.',
                                                        []
                                                    )
                                                ]
                                            ),
                                            goal('G1322',
                                                'Authorization checks are implemented at all APIs that expose PHR or exam data.',
                                                [],
                                                [
                                                    evidence(codeReviewAndApiSecurityTests,
                                                        'Code reviews, API security tests, and access control test cases confirm that authorization checks are implemented at all APIs that expose PHR or exam data.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    )
                                ]
                            )
                        ]
                    )
                ]
            ),
            goal('G2',
                'PHR and exam data in the Dr.Vida platform are protected against unauthorized modification, and their origin (device, clinician, or external service) is authentic and traceable.',
                [],
                [
                    strategy('Decompose by data lifecycle (ingestion, storage and modification, provenance) and by auditability (logging and traceability).',
                        [],
                        [
                            goal('G21',
                                'Input data between Dr.Vida and third-party systems is correctly and securely ingested.',
                                [],
                                [
                                    goal('G211',
                                        'Data exchanged between Dr.Vida APIs and third-party systems is verified as coming from authenticated sources.',
                                        [],
                                        [
                                            goal('G2111',
                                                'System identities or tokens asserting identity are validated before data is ingested.',
                                                [],
                                                [
                                                    evidence(apiGatewayAndOnboardingReview,
                                                        'API and gateway configuration tests, together with onboarding procedure reviews, confirm that identities or tokens asserting identity are validated before data is ingested.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    )
                                ]
                            ),
                            goal('G22',
                                'Stored PHR and exam data cannot be modified without authorization and traceability.',
                                [],
                                [
                                    goal('G221',
                                        'Write and modify operations on PHR data are restricted by authorization rules.',
                                        [],
                                        [
                                            goal('G2211',
                                                'Only roles with explicit permission (e.g., assigned clinician) may update specific PHR fields.',
                                                [],
                                                [
                                                    evidence(rbacPoliciesAndAuthorizationTests,
                                                        'RBAC policy documentation and authorization test cases confirm that only roles with explicit permission can update specific PHR fields.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    ),
                                    goal('G222',
                                        'Any changes to PHR entries and exam records are logged with who, when, and what was changed.',
                                        [],
                                        [
                                            goal('G2221',
                                                'Audit logs capture identifiers of user or service, timestamp, and affected records or fields.',
                                                [],
                                                [
                                                    evidence(logConfigurationReviewAndSampling,
                                                        'Log configuration reviews and log sampling confirm that audit logs capture user or service identifiers, timestamps, and affected records or fields.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    )
                                ]
                            )
                        ]
                    )
                ]
            ),
            goal('G3',
                "G3",
                [],
                [
                    strategy('Decompose into infrastructure resilience, backup and recovery, and monitoring and operational observability.',
                        [],
                        [
                            goal('G31',
                                'StabVida services for PHR access and sharing are resilient to common failures.',
                                [],
                                [
                                    goal('G311',
                                        'There is redundancy (e.g., multi-zone or multi-node deployment) for key backend services and storage.',
                                        [],
                                        [
                                            goal('G3111',
                                                'Deployment architecture includes failover for core APIs and databases.',
                                                [],
                                                [
                                                    evidence(architectureAndDeploymentReview,
                                                        'Architecture diagrams and deployment configuration inspections confirm that failover is in place for core APIs and databases.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    ),
                                    goal('G312',
                                        'Security controls (e.g., rate limiting, DDoS protection) protect against overloads without unduly preventing legitimate access.',
                                        [],
                                        [
                                            goal('G3121',
                                                'Rate limits and security filters are tuned and tested for realistic traffic patterns.',
                                                [],
                                                [
                                                    evidence(performanceAndSecurityTestResults,
                                                        'Performance and security testing tools confirm that rate limits and security filters are tuned and tested for realistic traffic patterns.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    )
                                ]
                            ),
                            goal('G32',
                                'PHR and exam data are recoverable in case of failures or incidents.',
                                [],
                                [
                                    goal('G321',
                                        'Regular backups of PHR databases and file storage are performed and retained according to policy.',
                                        [],
                                        [
                                            goal('G3211',
                                                'Backup jobs exist for all relevant data stores and run as scheduled.',
                                                [],
                                                [
                                                    evidence(backupConfigAndLogs,
                                                        'Backup job configurations and logs confirm that backups for all relevant data stores run as scheduled and are retained according to policy.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    ),
                                    goal('G322',
                                        'Data restoration procedures are defined and tested.',
                                        [],
                                        [
                                            goal('G3221',
                                                'At least one restore test has been successfully performed for PHR and exam data.',
                                                [],
                                                [
                                                    evidence(restoreTestReport,
                                                        'A restore test report confirms that restoration of PHR and exam data has been successfully performed.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    )
                                ]
                            ),
                            goal('G33',
                                'Availability issues are detected and handled promptly.',
                                [],
                                [
                                    goal('G331',
                                        'Key services are monitored (uptime, latency, error rates), with alerts on thresholds.',
                                        [],
                                        [
                                            goal('G3311',
                                                'Monitoring dashboards and alarms exist and are actively used.',
                                                [],
                                                [
                                                    evidence(monitoringConfigurationReview,
                                                        'A monitoring system configuration review confirms that monitoring dashboards and alarms exist and are actively used for key services.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    )
                                ]
                            )
                        ]
                    )
                ]
            ),
            goal('G4',
                'The handling of personal health and exam data by StabVida complies with applicable healthcare data protection laws, regulations, and relevant security standards.',
                [],
                [
                    strategy('Decompose into identification and mapping of applicable regulations, implementation of core legal and privacy obligations, and demonstration via risk assessment and documentation that the security controls in G1–G3 satisfy those obligations.',
                        [],
                        [
                            goal('G41',
                                'Applicable regulations and standards are identified and documented (e.g., GDPR, local health data laws, relevant security standards).',
                                [],
                                [
                                    goal('G411',
                                        'A regulatory mapping document lists each applicable law or standard and the relevant requirements.',
                                        [],
                                        [
                                            evidence(reviewedComplianceMatrix,
                                                'A compliance matrix reviewed by legal and compliance experts confirms that applicable regulations and standards and their relevant requirements are identified and documented.',
                                                []
                                            )
                                        ]
                                    )
                                ]
                            ),
                            goal('G43',
                                'Security controls described in G1–G3 are aligned with regulatory security requirements.',
                                [],
                                [
                                    goal('G431',
                                        'A security risk assessment has been performed and documented, linking identified risks to implemented controls.',
                                        [],
                                        [
                                            evidence(riskAssessmentReport,
                                                'A security risk assessment report documents identified risks and their associated controls.',
                                                []
                                            )
                                        ]
                                    ),
                                    goal('G432',
                                        'Documentation is maintained for technical and organizational measures to protect health data.',
                                        [],
                                        [
                                            evidence(securityPoliciesAndSops,
                                                'Security policy documents and standard operating procedures (SOPs) describe the technical and organizational measures used to protect health data.',
                                                []
                                            )
                                        ]
                                    )
                                ]
                            )
                        ]
                    )
                ]
            ),
            goal('G5',
                'Integration of StabVida systems with third-party external cloud data repositories or devices does not undermine security or privacy, and data ingestion paths from these sources are trustworthy.',
                [],
                [
                    strategy('Decompose into trust in devices and data sources (onboarding and authentication), security of IoMT and external data APIs, and management of third-party provider risk.',
                        [],
                        [
                            goal('G51',
                                'Only trusted devices and sources send data that becomes part of the PHR.',
                                [],
                                [
                                    goal('G511',
                                        'There is a defined onboarding and de-registration process for devices and external data sources.',
                                        [],
                                        [
                                            evidence(deviceOnboardingProceduresAndLogs,
                                                'Documented procedures and logs of device and external data source registration and de-registration confirm that a defined onboarding and de-registration process exists and is followed.',
                                                []
                                            )
                                        ]
                                    ),
                                    goal('G512',
                                        'Device and source authentication is enforced, consistent with the mechanisms described under G2111.',
                                        [],
                                        [
                                            evidence(enforcedApiGatewayAndOnboardingReview,
                                                'API and gateway configuration tests, together with onboarding procedure reviews, confirm that identities or tokens are validated before data is ingested.',
                                                []
                                            )
                                        ]
                                    )
                                ]
                            ),
                            goal('G52',
                                'APIs used for data ingestion and external sharing enforce security controls consistent with internal ones.',
                                [],
                                [
                                    goal('G521',
                                        'All IoMT integration APIs use proper authentication and authorization and apply rate limiting.',
                                        [],
                                        [
                                            evidence(apiSpecificationsAndSecurityTests,
                                                'API specification reviews and security testing tool results confirm that IoMT integration APIs use proper authentication/authorization and rate limiting.',
                                                []
                                            )
                                        ]
                                    ),
                                    goal('G522',
                                        'No direct external access to internal PHR databases is allowed; access is only via controlled APIs.',
                                        [],
                                        [
                                            evidence(architectureAndNetworkSecurityReview,
                                                'Architecture reviews and network security testing confirm that external entities cannot access PHR databases directly and must use controlled APIs.',
                                                []
                                            )
                                        ]
                                    )
                                ]
                            ),
                            goal('G53',
                                'Risks from third-party cloud data sources are managed.',
                                [],
                                [
                                    goal('G531',
                                        'Data-sharing agreements and contracts define security and privacy obligations for external providers.',
                                        [],
                                        [
                                            evidence(contractsAndDpas,
                                                'Documented contracts and Data Processing Agreements (DPAs) specify security and privacy obligations for external providers.',
                                                []
                                            )
                                        ]
                                    ),
                                    goal('G532',
                                        'Periodic security assessments of key third-party services are performed.',
                                        [],
                                        [
                                            evidence(vendorRiskAndSecurityReports,
                                                'Vendor risk assessments, SOC reports, and related security review documents confirm that periodic security assessments of key third-party services are performed.',
                                                []
                                            )
                                        ]
                                    )
                                ]
                            )
                        ]
                    )
                ]
            )
        ]
    )
).
