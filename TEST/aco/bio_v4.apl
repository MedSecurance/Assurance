
ac_pattern('BioAssist',
    [],
    goal('G0',
        "G0",
        [
            context("Case: BioAssist — Assured Use"),
            assumption('The cloud provider and underlying infrastructure (virtualization, storage, networking) implement appropriate physical and infrastructure-level security controls.'),
            assumption('Operating systems, databases, and middleware used by BioAssist are installed, configured, and kept patched according to defined security baselines.'),
            assumption('The surrounding network environment provides basic protections (e.g., firewalling, routing, segmentation) consistent with the assumed threat model.'),
            assumption('Healthcare professionals and other staff using BioAssist follow organizational security policies and receive appropriate security awareness training.'),
            assumption('End-user devices (e.g., clinicians’ workstations, patient mobile phones) and local facilities are protected physically, according to organizational policies.'),
            assumption('Users keep their authentication credentials confidential and follow organizational rules for credential management (e.g., not sharing passwords).')
        ],
        [
            goal('G1',
                'PHR and multimedia data in the BioAssist platform are adequately protected against unauthorized disclosure during collection, storage, and sharing.',
                [],
                [
                    strategy('Decompose by data state (in transit, at rest) and by access control for different user and service channels (patients, clinicians, internal services, external services).',
                        [],
                        [
                            goal('G11',
                                'Data in transit between clients and the BioAssist cloud is confidential.',
                                [],
                                [
                                    goal('G111',
                                        'All communications between client applications (patient and clinician apps) and the BioAssist cloud endpoint use strong, up-to-date transport encryption.',
                                        [],
                                        [
                                            goal('G1111',
                                                'TLS (or equivalent) is implemented with strong cipher suites and protocol versions, and no insecure fallback is possible.',
                                                [],
                                                [
                                                    evidence(tlsConfigurationScanReport,
                                                        'A TLS configuration scan report for the BioAssist endpoints shows only approved protocol versions and cipher suites and confirms that insecure fallback is not possible.',
                                                        []
                                                    )
                                                ]
                                            ),
                                            goal('G1112',
                                                'Certificates used for client-to-cloud communications are valid, not expired, issued by trusted CAs, and protected from misuse.',
                                                [],
                                                [
                                                    evidence(certificateManagementReview,
                                                        'A certificate inventory and management review, together with automated certificate checks, confirms that all certificates used for client-to-cloud communications are valid, trusted, and properly protected.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    ),
                                    goal('G112',
                                        'Data in transit between BioAssist services and external cloud data sources (sensors, wearables, other cloud APIs) is encrypted and authenticated.',
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
                                'PHR and multimedia data at rest in BioAssist cloud storage are confidential.',
                                [],
                                [
                                    goal('G121',
                                        'All PHR data and uploaded multimedia (images, test scans) stored in cloud databases and object storage are encrypted at rest.',
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
                                'Only authorized users and components can access PHR and multimedia data.',
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
                                        'End-user access to PHR data (patients and clinicians) is enforced by robust authentication and authorization mechanisms.',
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
                                                'Authorization checks are implemented at all APIs that expose PHR or multimedia data.',
                                                [],
                                                [
                                                    evidence(codeReviewAndApiSecurityTests,
                                                        'Code reviews, API security tests, and access control test cases confirm that authorization checks are implemented at all APIs that expose PHR or multimedia data.',
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
                'PHR and multimedia data in the BioAssist platform are protected against unauthorized modification, and their origin (patient, device, clinician, or external service) is authentic and traceable.',
                [],
                [
                    strategy('Decompose by data lifecycle (ingestion, storage and modification, provenance) and by auditability (logging and traceability).',
                        [],
                        [
                            goal('G21',
                                'Sensor, wearable, and manual input data is correctly and securely ingested.',
                                [],
                                [
                                    goal('G211',
                                        'Data received from sensors and wearables is verified as coming from authenticated devices or sources.',
                                        [],
                                        [
                                            goal('G2111',
                                                'Device identities or tokens are validated before data is ingested.',
                                                [],
                                                [
                                                    evidence(apiGatewayAndOnboardingReview,
                                                        'API and gateway configuration tests, together with device onboarding procedure reviews, confirm that device identities or tokens are validated before data is ingested.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    ),
                                    goal('G212',
                                        'Client-side inputs (forms, questionnaires, uploaded images) are validated and protected against tampering or manipulation in transit.',
                                        [],
                                        [
                                            goal('G2121',
                                                'Input validation and integrity checks exist for PHR fields and file uploads.',
                                                [],
                                                [
                                                    evidence(codeReviewAndSecurityTesting,
                                                        'Code reviews and security testing (e.g., fuzzing, input validation tests) confirm that input validation and integrity checks exist for PHR fields and file uploads.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    )
                                ]
                            ),
                            goal('G22',
                                'Stored PHR and multimedia data cannot be modified without authorization and traceability.',
                                [],
                                [
                                    goal('G221',
                                        'Write and modify operations on PHR data are restricted by authorization rules.',
                                        [],
                                        [
                                            goal('G2211',
                                                'Only roles with explicit permission (e.g., patient, assigned clinician) may update specific PHR fields.',
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
                                        'Any changes to PHR entries and multimedia records are logged with who, when, and what was changed.',
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
                            ),
                            goal('G23',
                                'Data provenance (who or what created or modified data) is preserved.',
                                [],
                                [
                                    goal('G231',
                                        'Each PHR item carries metadata about its origin (patient, clinician, device, external service).',
                                        [],
                                        [
                                            goal('G2311',
                                                'The data schema includes provenance fields and they are consistently populated.',
                                                [],
                                                [
                                                    evidence(schemaReviewAndDataSampling,
                                                        'Schema reviews and data sampling scripts confirm that provenance fields exist and are consistently populated for PHR items.',
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
                                'Critical BioAssist services for PHR access and sharing are resilient to common failures.',
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
                                'PHR and multimedia data are recoverable in case of failures or incidents.',
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
                                                'At least one restore test has been successfully performed for PHR and multimedia data.',
                                                [],
                                                [
                                                    evidence(restoreTestReport,
                                                        'A restore test report confirms that restoration of PHR and multimedia data has been successfully performed.',
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
                'BioAssist data-sharing mechanisms accurately enforce patient consent, authorization, and time limits, preventing unauthorized access to PHR and multimedia data.',
                [],
                [
                    strategy('Decompose into policy definition (how patients express sharing intent), policy enforcement (including group semantics), and temporal control and revocation (time-limited access and revocation), supported by testing and auditability.',
                        [],
                        [
                            goal('G41',
                                'Patients are able to define sharing policies in a clear and correct manner.',
                                [],
                                [
                                    goal('G411',
                                        'User interfaces for sharing allow patients to clearly specify which PHR items/files to share, with which users/groups, and for how long.',
                                        [],
                                        [
                                            goal('G4111',
                                                "G4111",
                                                [],
                                                [
                                                    evidence(usabilityAndFunctionalTestEvidence,
                                                        "usabilityAndFunctionalTestEvidence",
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    )
                                ]
                            ),
                            goal('G42',
                                'Implemented sharing mechanisms enforce the specified policies without unauthorized access.',
                                [],
                                [
                                    goal('G421',
                                        'Access control logic checks both user identity and sharing rules for each access request.',
                                        [],
                                        [
                                            goal('G4211',
                                                'Automated tests cover typical and edge-case sharing scenarios (e.g., wrong user, revoked access).',
                                                [],
                                                [
                                                    evidence(functionalRegressionAndSecurityTests,
                                                        'Functional and regression test suites, together with security tests, confirm that access control logic correctly enforces sharing rules for typical and edge-case scenarios.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    ),
                                    goal('G422',
                                        'Group sharing semantics (user groups/organizations) are correctly resolved and updated.',
                                        [],
                                        [
                                            goal('G4221',
                                                'Changes in group membership are reflected promptly in access rights.',
                                                [],
                                                [
                                                    evidence(groupChangeSimulationTests,
                                                        'Tests simulating group membership changes and subsequent access attempts confirm that access rights are updated promptly.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    )
                                ]
                            ),
                            goal('G43',
                                'Time-limited access is strictly enforced.',
                                [],
                                [
                                    goal('G431',
                                        'For each share, start and end timestamps are stored and checked at access time.',
                                        [],
                                        [
                                            goal('G4311',
                                                'Access requests after the expiry time are systematically denied.',
                                                [],
                                                [
                                                    evidence(expiryEnforcementTests,
                                                        'Automated test cases and security tests confirm that access requests after the expiry time are systematically denied.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    ),
                                    goal('G432',
                                        'System time sources and time zone handling are well-defined to avoid timing ambiguities.',
                                        [],
                                        [
                                            goal('G4321',
                                                'Time synchronization and time-zone handling are specified and implemented consistently.',
                                                [],
                                                [
                                                    evidence(timeHandlingDesignAndTests,
                                                        'Design reviews and time-handling tests confirm that time synchronization and time-zone handling are specified and implemented consistently.',
                                                        []
                                                    )
                                                ]
                                            )
                                        ]
                                    )
                                ]
                            ),
                            goal('G44',
                                'Patients are able to revoke sharing, and such revocation is enforced and recorded.',
                                [],
                                [
                                    goal('G441',
                                        'The UI allows patients to see active shares and revoke them.',
                                        [],
                                        [
                                            evidence(usabilityAndFunctionalEvidenceForRevocationUi,
                                                'Usability tests and functional tests confirm that patients can view active shares and revoke them through the UI.',
                                                []
                                            )
                                        ]
                                    ),
                                    goal('G442',
                                        'After revocation, no further access occurs via the revoked share.',
                                        [],
                                        [
                                            evidence(postRevocationAccessTests,
                                                'Test cases and penetration tests confirm that access via a revoked share is no longer possible after revocation.',
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
                'The handling of personal health and multimedia data by BioAssist complies with applicable healthcare data protection laws, regulations, and relevant security standards.',
                [],
                [
                    strategy('Decompose into identification and mapping of applicable regulations, implementation of core legal and privacy obligations, and demonstration via risk assessment and documentation that the security controls in G1–G4 satisfy those obligations.',
                        [],
                        [
                            goal('G51',
                                'Applicable regulations and standards are identified and documented (e.g., GDPR, local health data laws, relevant security standards).',
                                [],
                                [
                                    goal('G511',
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
                            goal('G52',
                                'Core legal obligations for personal health data are implemented (e.g., lawful basis, consent, data minimization, purpose limitation, data subject rights).',
                                [],
                                [
                                    goal('G521',
                                        'Mechanisms for obtaining and documenting patient consent are implemented and traceable.',
                                        [],
                                        [
                                            evidence(consentDesignReviewAndTests,
                                                'Design reviews and consent flow tests confirm that mechanisms for obtaining and documenting patient consent are implemented and traceable.',
                                                []
                                            )
                                        ]
                                    ),
                                    goal('G522',
                                        "G522",
                                        [],
                                        [
                                            evidence(functionalTestsAndSupportProcedures,
                                                "functionalTestsAndSupportProcedures",
                                                []
                                            )
                                        ]
                                    )
                                ]
                            ),
                            goal('G53',
                                'Security controls described in G1–G4 are aligned with regulatory security requirements.',
                                [],
                                [
                                    goal('G531',
                                        'A security risk assessment has been performed and documented, linking identified risks to implemented controls.',
                                        [],
                                        [
                                            evidence(riskAssessmentReport,
                                                'A security risk assessment report documents identified risks and their associated controls.',
                                                []
                                            )
                                        ]
                                    ),
                                    goal('G532',
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
            goal('G6',
                'Integration of sensors, wearable devices, and external cloud data sources into BioAssist does not undermine security or privacy, and data ingestion paths from these sources are trustworthy.',
                [],
                [
                    strategy('Decompose into trust in devices and data sources (onboarding and authentication), security of IoMT and external data APIs, and management of third-party provider risk.',
                        [],
                        [
                            goal('G61',
                                'Only trusted devices and sources send data that becomes part of the PHR.',
                                [],
                                [
                                    goal('G611',
                                        'There is a defined onboarding and de-registration process for devices and external data sources.',
                                        [],
                                        [
                                            evidence(deviceOnboardingProceduresAndLogs,
                                                'Documented procedures and logs of device and external data source registration and de-registration confirm that a defined onboarding and de-registration process exists and is followed.',
                                                []
                                            )
                                        ]
                                    ),
                                    goal('G612',
                                        'Device and source authentication is enforced, consistent with the mechanisms described under G2111.',
                                        [],
                                        [
                                            evidence(enforcedApiGatewayAndOnboardingReview,
                                                'API and gateway configuration tests, together with device onboarding procedure reviews, confirm that device identities or tokens are validated before data is ingested.',
                                                []
                                            )
                                        ]
                                    )
                                ]
                            ),
                            goal('G62',
                                'APIs used for data ingestion and external sharing enforce security controls consistent with internal ones.',
                                [],
                                [
                                    goal('G621',
                                        'All IoMT integration APIs use proper authentication and authorization and apply rate limiting.',
                                        [],
                                        [
                                            evidence(apiSpecificationsAndSecurityTests,
                                                'API specification reviews and security testing tool results confirm that IoMT integration APIs use proper authentication/authorization and rate limiting.',
                                                []
                                            )
                                        ]
                                    ),
                                    goal('G622',
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
                            goal('G63',
                                'Risks from third-party cloud data sources are managed.',
                                [],
                                [
                                    goal('G631',
                                        'Data-sharing agreements and contracts define security and privacy obligations for external providers.',
                                        [],
                                        [
                                            evidence(contractsAndDpas,
                                                'Documented contracts and Data Processing Agreements (DPAs) specify security and privacy obligations for external providers.',
                                                []
                                            )
                                        ]
                                    ),
                                    goal('G632',
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
