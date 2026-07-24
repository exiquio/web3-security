Written pre-assessment-questionaire.md
 Test

**Date:** 2026-07-24
**Assessed by:** [Name]

## Documentation and Planning

### 1. Do you have all actors, roles, and privileges documented?
> Document who can do what in your system. This includes admin roles, privileged operations, and the scope of each role's permissions.
- [ ] Yes
- [ ] No
[Answer notes]

### 2. Do you keep documentation of all external services, contracts, and oracles you rely on?
> Maintain an up-to-date list of all external dependencies, including third-party contracts, oracles, bridges, and off-chain services your system interacts with.
- [ ] Yes
- [ ] No
[Answer notes]

### 3. Do you have a written and tested incident response plan?
> Have a documented plan for responding to security incidents. Test it regularly through tabletop exercises.
- [ ] Yes
- [ ] No
[Answer notes]

### 4. Do you document the best ways to attack your system?
> Maintain a threat model that identifies potential attack vectors. Update it as your system evolves.
- [ ] Yes
- [ ] No
[Answer notes]

## Personnel and Access Control

### 5. Do you perform identity verification and background checks on all employees?
> Verify the identity of team members, especially those with access to privileged systems or keys.
- [ ] Yes
- [ ] No
[Answer notes]

### 6. Do you have a team member with security defined in their role?
> Assign explicit security responsibilities to at least one team member. Security should not be an afterthought.
- [ ] Yes
- [ ] No
[Answer notes]

### 7. Do you require hardware security keys for production systems?
> Use hardware security keys (like YubiKeys) for accessing production systems and critical infrastructure.
- [ ] Yes
- [ ] No
[Answer notes]

### 8. Does your key management system require multiple humans and physical steps?
> Implement multi-signature schemes and physical security measures for critical operations. No single person should be able to compromise the system.
- [ ] Yes
- [ ] No
[Answer notes]

## Technical Security

### 9. Do you define key invariants for your system and test them on every commit?
> Identify the properties that must always hold true in your system and verify them automatically. Use tools like Echidna or Medusa to test invariants continuously.
- [ ] Yes
- [ ] No
[Answer notes]

### 10. Do you use the best automated tools to discover security issues in your code?
> Integrate security tools into your development workflow: Slither for static analysis; Echidna or Medusa for fuzzing.
- [ ] Yes
- [ ] No
[Answer notes]

### 11. Do you undergo external audits and maintain a vulnerability disclosure or bug bounty program?
> Get independent security reviews before major releases. Maintain a way for security researchers to responsibly report vulnerabilities.
- [ ] Yes
- [ ] No
[Answer notes]

### 12. Have you considered and mitigated avenues for abusing users of your system?
> Think beyond technical exploits. Consider how your system could be used to harm users through phishing, social engineering, or economic attacks.
- [ ] Yes
- [ ] No
[Answer notes]
