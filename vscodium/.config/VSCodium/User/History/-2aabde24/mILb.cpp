#include "Representations/BehaviorControl/FieldBall.h"
#include "Representations/BehaviorControl/PathPlanner.h"
#include "Representations/BehaviorControl/Skills.h"
#include "Representations/Communication/GameInfo.h"
#include "Representations/Communication/TeamInfo.h"
#include "Representations/Configuration/FieldDimensions.h"
#include "Representations/Modeling/RobotPose.h"
#include "Representations/MotionControl/HeadMotionEngineOutput.h"
#include "Representations/Perception/ObstaclesPercepts/ObstaclesFieldPercept.h"
#include "Tools/BehaviorControl/Framework/Card/CabslCard.h"
#include "Tools/BehaviorControl/Framework/Card/Card.h"
#include "Tools/BehaviorControl/Framework/Card/Dealer.h"
#include "Tools/Math/BHMath.h"

CARD(FullBackKickOffCard, {
                              ,
                              CALLS(Activity),
                              CALLS(InWalkKick),
                              CALLS(LookForward),
                              CALLS(Stand),
                              CALLS(WalkAtRelativeSpeed),
                              CALLS(WalkToTarget),
                              CALLS(KeyFrameArms),
                              CALLS(Kick),
                              CALLS(PathToTarget),
                              CALLS(LookAtAngles),
                              CALLS(LookAtPoint),
                              CALLS(Say),
                              REQUIRES(FieldBall),
                              REQUIRES(FieldDimensions),
                              REQUIRES(RobotPose),
                              REQUIRES(GameInfo),
                              REQUIRES(OwnTeamInfo),
                              REQUIRES(HeadMotionEngineOutput),
                              DEFINES_PARAMETERS({
                                  ,
                                  (int)(1000)initialWaitTime,
                                  (int)(3000)ballNotSeenTimeout,
                                  (int)(7000)ballNotSeenTimeoutWhenPathTo,
                                  (int)(3500)searchForBallTimeLimit,
                                  (int)(1000)searchForBallTimeMin,
                                  (int)(5000)freeKickWaitTime,
                                  (int)(10000)freeKickTimeLimit,
                                  (float)(0.8f)walkSpeed,
                                  (float)(-3900.f)ourGoalAreaX,
                                  (float)(300.f)ballAlignOffsetX,
                                  (float)(100.f)ballYThreshold,
                                  (float)(500.f)ballNearThreshold,
                                  (float)(120.f)ballOffsetX,
                                  (float)(35.f)ballOffsetY,
                                  (float)(-2000.f)myTerritoryX,
                                  (float)(1100.f)myTerritoryY,
                                  (Angle)(15_deg)angleFreeKickThreshold,
                                  (Angle)(3_deg)angleFreeKickThresholdPrecise,
                                  (Angle)(5_deg)ballAlignThreshold,
                                  (Rangef)({100.f, 140.f})ballOffsetXRange,
                                  (Rangef)({20.f, 50.f})ballOffsetYRange,
                                  (Vector2f)(4500.f, 3000.f)leftFreeKick,
                                  (Vector2f)(4500.f, -3000.f)rightFreeKick,
                              }),
                          });

class FullBackKickOffCard : public FullBackKickOffCardBase {
  bool preconditions() const override {
    if (theGameInfo.state == STATE_PLAYING && theGameInfo.secsRemaining > 585)
      return true;
    else
      return false;
  }

  bool postconditions() const override {
    if (theGameInfo.secsRemaining < 585)
      return true;
    else
      return false;
  }

  option {
    theActivitySkill(BehaviorStatus::FullBackBehavior);
    float tilt = 0.38f;

    initial_state(start) {
      transition {
        if (state_time > initialWaitTime) {
          if (theFieldBall.ballWasSeen()) {
            if (theGameInfo.kickingTeam == theOwnTeamInfo.teamNumber)
              goto walkToBall;
            else
              goto walkToDefencePoint;
          } else
            goto searchForBallLeft;
        }
      }

      action {
        theLookForwardSkill();
        theStandSkill();
      }
    }

    state(searchForBall) {
      transition {
        if (theFieldBall.ballWasSeen()) {
          if (theGameInfo.kickingTeam == theOwnTeamInfo.teamNumber)
            goto walkToBall;
          else
            goto walkToDefencePoint;
        } else if (state_time > searchForBallTimeLimit)
          goto searchForBallRight;
      }

      action {
        theLookForwardSkill();
        theWalkAtRelativeSpeedSkill(Pose2f(walkSpeed, 0.f, 0.f));
      }
    }

    state(searchForBallRight) {
      transition {
        if (theFieldBall.ballWasSeen()) {
          if (theGameInfo.kickingTeam == theOwnTeamInfo.teamNumber)
            goto walkToBall;
          else
            goto walkToDefencePoint;
        } else if (theLookAtAnglesSkill.isDone() &&
                   state_time > searchForBallTimeMin)
          goto searchForBallLeft;
      }

      action {
        theStandSkill();
        theLookAtAnglesSkill(-120_deg, tilt, 60_deg,
                             HeadMotionRequest::autoCamera);
      }
    }

    state(searchForBallLeft) {
      transition {
        if (theFieldBall.ballWasSeen()) {
          if (theGameInfo.kickingTeam == theOwnTeamInfo.teamNumber)
            goto walkToBall;
          else
            goto walkToDefencePoint;
        } else if (theLookAtAnglesSkill.isDone() &&
                   state_time > searchForBallTimeMin)
          goto searchForBall;
      }

      action {
        theStandSkill();
        theLookAtAnglesSkill(120_deg, tilt, 60_deg,
                             HeadMotionRequest::autoCamera);
      }
    }

    state(walkToDefencePoint) {
      transition {
        if (!theFieldBall.ballWasSeen(ballNotSeenTimeout)) {
          if (theFieldBall.recentBallEndPositionRelative().y() > 0)
            goto searchForBallLeft;
          else
            goto searchForBallRight;
        }
      }

      action {
        // theKeyFrameArmsSkill(ArmKeyFrameRequest::ArmKeyFrameId::back);
        theLookAtPointSkill(Vector3f(theFieldBall.positionRelative.x(),
                                     theFieldBall.positionRelative.y(), -25.f));
        Pose2f pos = theRobotPose.inversePose * Vector2f(-750, -750);
        theWalkToTargetSkill(Pose2f(walkSpeed, walkSpeed, walkSpeed),
                             Pose2f(theFieldBall.positionRelative.angle(),
                                    pos.translation.x(), pos.translation.y()));
      }
    }

    state(walkToBall) {
      transition {
        if (!theFieldBall.ballWasSeen(ballNotSeenTimeout)) {
          if (theFieldBall.recentBallEndPositionRelative().y() > 0)
            goto searchForBallLeft;
          else
            goto searchForBallRight;
        } else if (theFieldBall.positionRelative.squaredNorm() <
                   sqr(ballNearThreshold))
          goto turnToBall;
      }

      action {
        // theKeyFrameArmsSkill(ArmKeyFrameRequest::ArmKeyFrameId::back);
        theLookAtPointSkill(Vector3f(theFieldBall.positionRelative.x(),
                                     theFieldBall.positionRelative.y(), -25.f));
        // thePathToTargetSkill(walkSpeed,theFieldBall.positionOnField);
        theWalkToTargetSkill(Pose2f(walkSpeed, walkSpeed, walkSpeed),
                             theFieldBall.positionRelative);
      }
    }

    state(turnToBall) {
      transition {
        if (!theFieldBall.ballWasSeen(ballNotSeenTimeout)) {
          if (theFieldBall.recentBallEndPositionRelative().y() > 0)
            goto searchForBallLeft;
          else
            goto searchForBallRight;
        } else if (std::abs(theFieldBall.positionRelative.angle()) <
                   ballAlignThreshold)
          goto alignToFreeKick;
      }

      action {
        // theKeyFrameArmsSkill(ArmKeyFrameRequest::ArmKeyFrameId::back);
        theLookForwardSkill();
        theWalkToTargetSkill(
            Pose2f(walkSpeed, walkSpeed, walkSpeed),
            Pose2f(theFieldBall.positionRelative.angle(), 0.f, 0.f));
      }
    }

    state(alignToFreeKick) {
      const Angle angleFreeKick = calcAngleFreeKick();

      transition {
        if (!theFieldBall.ballWasSeen(ballNotSeenTimeout)) {
          if (theFieldBall.recentBallEndPositionRelative().y() > 0)
            goto searchForBallLeft;
          else
            goto searchForBallRight;
        }
        if (std::abs(angleFreeKick) < angleFreeKickThreshold &&
            std::abs(theFieldBall.positionRelative.y()) < ballYThreshold)
          goto alignBehindBallToFreeKick;
      }

      action {
        // theKeyFrameArmsSkill(ArmKeyFrameRequest::ArmKeyFrameId::back);
        theLookForwardSkill();
        theWalkToTargetSkill(
            Pose2f(walkSpeed, walkSpeed, walkSpeed),
            Pose2f(angleFreeKick,
                   theFieldBall.positionRelative.x() - ballAlignOffsetX,
                   theFieldBall.positionRelative.y()));
      }
    }

    state(alignBehindBallToFreeKick) {
      const Angle angleFreeKick = calcAngleFreeKick();

      transition {
        if (!theFieldBall.ballWasSeen(ballNotSeenTimeout)) {
          if (theFieldBall.recentBallEndPositionRelative().y() > 0)
            goto searchForBallLeft;
          else
            goto searchForBallRight;
        }
        if (std::abs(angleFreeKick) < angleFreeKickThresholdPrecise &&
            ballOffsetXRange.isInside(theFieldBall.positionRelative.x()) &&
            ballOffsetYRange.isInside(theFieldBall.positionRelative.y()))
          goto freeKick;
      }

      action {
        theLookForwardSkill();
        // theKeyFrameArmsSkill(ArmKeyFrameRequest::ArmKeyFrameId::back);
        theWalkToTargetSkill(
            Pose2f(walkSpeed, walkSpeed, walkSpeed),
            Pose2f(angleFreeKick,
                   theFieldBall.positionRelative.x() - ballOffsetX,
                   theFieldBall.positionRelative.y() - ballOffsetY));
      }
    }

    state(freeKick) {
      const Angle angleToKick = calcAngleFreeKick();

      transition {
        if (state_time > freeKickTimeLimit || theKickSkill.isDone()) {
          goto start;
        }
      }

      action {
        if (theGameInfo.secondaryTime < 2)
          theKickSkill(KickRequest::KickMotionID::kickForward, true, 3000);
      }
    }
  }

  bool isMyTerritory() {
    if (theFieldBall.positionOnField.x() > myTerritoryX ||
        theFieldBall.positionOnField.x() < ourGoalAreaX)
      return false;
    else if (fabs(theFieldBall.positionOnField.y()) > myTerritoryY)
      return false;
    else
      return true;
  }

  Pose2f calcPoseToSide() const {
    if (theFieldBall.positionOnField.y() > 0)
      return (theRobotPose.inversePose *
              Vector2f(theFieldBall.positionOnField.x(),
                       theFieldBall.positionOnField.y() - ballOffsetY));
    else
      return (theRobotPose.inversePose *
              Vector2f(theFieldBall.positionOnField.x(),
                       theFieldBall.positionOnField.y() + ballOffsetY));
  }

  Angle calcAngleFreeKick() const {
    return (theRobotPose.inversePose * leftFreeKick).angle();
  }

  Pose2f calcDefencePoint() {
    float ballx = theFieldBall.positionOnField.x();
    float bally = theFieldBall.positionOnField.y();
    float k = bally / (ballx + 4500);
    float b = (4500 * bally) / (ballx + 4500);
    float y = k * myTerritoryX + b;
    if (fabs(y) < myTerritoryY)
      return (theRobotPose.inversePose * Vector2f(myTerritoryX, y));
    else {
      float x = (myTerritoryY - b) / k;
      if (x < myTerritoryX && x > -3900.f)
        return (theRobotPose.inversePose * Vector2f(x, myTerritoryY));
      else {
        x = (0 - myTerritoryY - b) / k;
        if (x < myTerritoryX && x > -3900.f)
          return (theRobotPose.inversePose * Vector2f(x, 0 - myTerritoryY));
        else if (bally > 0)
          return (theRobotPose.inversePose * Vector2f(-3900.f, myTerritoryY));
        else
          return (theRobotPose.inversePose *
                  Vector2f(-3900.f, 0 - myTerritoryY));
      }
    }
  }
};

MAKE_CARD(FullBackKickOffCard);