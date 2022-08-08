import {
  ProposalExecuted
} from "../generated/ZDAOModule/ZDAOModule";
import { ExecutedProposal } from "../generated/schema";
import { log } from "@graphprotocol/graph-ts";

export function handleProposalExecuted(event: ProposalExecuted): void {
  const platformType = event.params._platformType.toI32();
  const proposalHash = event.params._proposalHash;
  const token = event.params._token;
  const recipient = event.params._to;
  const amount = event.params._amount;

  log.info("handleProposalExecuted, called {}, {}", [platformType.toString(), proposalHash.toHexString()]);

  const id = `${platformType}-${proposalHash}`;
  const proposal: ExecutedProposal = new ExecutedProposal(id);
  proposal.platformType = platformType;
  proposal.proposalHash = proposalHash;
  proposal.token = token;
  proposal.recipient = recipient;
  proposal.amount = amount;
  proposal.save();
}